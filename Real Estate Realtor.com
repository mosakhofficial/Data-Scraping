import requests
from bs4 import BeautifulSoup
import pandas as pd
import time
import random

def get_random_headers():
    user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.85 Safari/537.36",
        # Add more User-Agent strings if needed
    ]
    headers = {
        "User-Agent": random.choice(user_agents),
        "Accept-Language": "en-US,en;q=0.5",
        "Referer": "https://www.google.com",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Connection": "keep-alive"
    }
    return headers

def scrape_agents(base_urls):
    agents = []
    session = requests.Session()

    for base_url in base_urls:
        page = 1
        while True:
            url = f"{base_url}/pg-{page}"
            print(f"Scraping URL: {url}")  # Debugging line
            
            # Retry mechanism for handling 403 errors
            retries = 3
            while retries > 0:
                response = session.get(url, headers=get_random_headers())
                if response.status_code == 200:
                    break
                else:
                    print(f"Failed to retrieve the webpage. Status code: {response.status_code}")
                    retries -= 1
                    if retries == 0:
                        print("Max retries reached. Moving to the next URL.")
                        return agents
                    time.sleep(random.uniform(5, 10))  # Wait before retrying

            soup = BeautifulSoup(response.text, 'html.parser')

            # Extract agent cards
            agent_cards = soup.find_all('div', class_='agent-list-card')

            if not agent_cards:
                print(f"No more agents found on page {page}. Ending scraping for {base_url}.")
                break

            valid_agent_found = False
            for card in agent_cards:
                # Extract the name, company, and phone using updated selectors
                name_element = card.find('div', class_='agent-name')
                company_element = card.find('div', class_='base__StyledType-rui__sc-108xfm0-0 bcGnxR')
                phone_element = card.find('div', class_='jsx-3873707352 agent-phone hidden-xs hidden-xxs')

                name = name_element.text.strip() if name_element else 'N/A'
                company = company_element.text.strip() if company_element else 'N/A'
                phone = phone_element.text.strip() if phone_element else 'N/A'

                if name != 'N/A' and company != 'N/A' and phone != 'N/A':
                    valid_agent_found = True

                agent_data = {
                    'Name': name,
                    'Company': company,
                    'Phone': phone
                }

                # Check for duplicates before adding
                if agent_data not in agents:
                    agents.append(agent_data)

            if not valid_agent_found:
                print(f"No valid agents found on page {page}. Ending scraping for {base_url}.")
                break

            # Print the data extracted for the current page for debugging purposes
            print(f"Page {page} extracted data for {base_url}:")
            for agent in agents[-len(agent_cards):]:  # Only print agents from the current page
                print(agent)

            # Check if there is a next page
            next_page_button = soup.select_one('a[href*="pg-"]')
            if not next_page_button or 'disabled' in next_page_button.attrs.get('class', []):
                print("No next page found. Scraping complete.")
                break

            # Random delay to mimic human behavior
            time.sleep(random.uniform(5, 10))
            page += 1

    return agents

# List of URLs to scrape
urls = [
    "https://www.realtor.com/realestateagents/Bentonville_oh",
"https://www.realtor.com/realestateagents/Manchester_oh",
"https://www.realtor.com/realestateagents/Blue-Creek_oh",
"https://www.realtor.com/realestateagents/Cherry-Fork_oh",
"https://www.realtor.com/realestateagents/Lynx_oh",
"https://www.realtor.com/realestateagents/Peebles_oh",
"https://www.realtor.com/realestateagents/Seaman_oh",
"https://www.realtor.com/realestateagents/West-Union_oh",
    # Add more base URLs as needed
]

# Scrape agents from the list of URLs
print(f"Scraping agents from: {urls}")
agents_data = scrape_agents(urls)

# Convert to DataFrame and save to Excel
df = pd.DataFrame(agents_data)
df.to_excel('US_OH_Realtor.xlsx', index=False)

# Uncomment the following line to run the script in the interpreter
# scrape_agents(urls)
