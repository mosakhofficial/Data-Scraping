import requests
from bs4 import BeautifulSoup
import pandas as pd
import random
from time import sleep

def get_random_user_agent():
    user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
        # Add more user agents if needed
    ]
    return random.choice(user_agents)

def scrape_zillow_agents(base_url):
    agents = []
    page = 1

    while True:
        url = f"{base_url}?page={page}"
        headers = {
            "User-Agent": get_random_user_agent(),
            "Referer": "https://www.zillow.com/",
            "Accept-Language": "en-US,en;q=0.9",
        }

        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(f"HTTP error occurred: {err}")
            break
        except requests.exceptions.RequestException as err:
            print(f"Request error occurred: {err}")
            sleep(2)  # Wait a bit before retrying
            continue
        
        soup = BeautifulSoup(response.text, 'html.parser')

        # Extract agent cards
        agent_cards = soup.find_all('div', class_='Summary__StyledFlex-sc-130ry7i-0')

        if not agent_cards:
            print(f"No more agents found on page {page}. Ending scraping.")
            break

        new_agents = []

        for card in agent_cards:
            # Extract the name, phone number, and company
            name_element = card.find('a', class_='StyledTextButton-c11n-8-101-0__sc-1nwmfqo-0')
            phone_element = card.find('div', class_='Text-c11n-8-101-0__sc-aiai24-0 fdbIQH')
            company_element = card.find_all('div', class_='Text-c11n-8-101-0__sc-aiai24-0 bpNrGo')

            name = name_element.text.strip() if name_element else 'N/A'
            phone = phone_element.text.strip() if phone_element else 'N/A'
            company = company_element[0].text.strip() if company_element else 'N/A'

            new_agents.append({
                'Name': name,
                'Phone': phone,
                'Company': company
            })

        agents.extend(new_agents)

        # Print the data extracted for the current page
        print(f"Page {page} extracted data:")
        for agent in new_agents:
            print(agent)

        next_page_button = soup.find('button', {'title': 'Next page'})
        if not next_page_button or next_page_button.get('aria-disabled') == 'true':
            print("No next page found. Scraping complete.")
            break

        page += 1
        sleep(random.uniform(1, 3))  # Random delay to avoid detection

    return agents

zillow_urls = [
    "https://www.zillow.com/professionals/real-estate-agent-reviews/jacksonville-fl/"
    # Add your URLs here
]

all_agents = []

for url in zillow_urls:
    print(f"Scraping agents from: {url}")
    agents_data = scrape_zillow_agents(url)
    all_agents.extend(agents_data)

df = pd.DataFrame(all_agents)
df.to_excel('US_FL_Zillow.xlsx', index=False)

# Uncomment the following line to run the script in the interpreter
# scrape_zillow_agents(zillow_urls)
