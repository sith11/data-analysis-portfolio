# -*- coding: utf-8 -*-
"""
Created on Tue Feb 16 11:09:14 2021
@author: WL-133

"""
#-----------------------------------------------------Import------------------------------------------------------------

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from bs4 import BeautifulSoup as soup
import pandas as pd
import time
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import TimeoutException
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import UnexpectedAlertPresentException
import os.path
import pickle
startTime = time.time()

#----------------------------------------------Browser Initialisation---------------------------------------------------

url = 'https://www.societe.com/'
path = r'C:\Users\WL-133\anaconda3\Lib\site-packages\selenium\webdriver\chrome\chromedriver.exe'
path1 = r'C:\Users\WL-133\anaconda3\Lib\site-packages\selenium\webdriver\firefox'
#driver = webdriver.Chrome(path)
# options = Options()
# options.add_argument('--ignore-certificate-errors')
# options.add_argument('--disable-application-cache')
# options.headless = True
# options.add_argument('--disable-gpu')
# options.add_argument('--headless')
driver = webdriver.Chrome(path)
driver.get(url)

#---------------------------------------------------Webscraping---------------------------------------------------------

class PickleRick:
    def __init__(self, comp_names):
        self.siret = []
        self.tva = []
        self.naf = []
        self.emp = []
        self.chif = []
        self.comp_names = comp_names
        self.position = 0

    def find_field(self, driver, xpath):
        try:
            return driver.find_element_by_xpath(xpath).text
        except NoSuchElementException:
            return 'Not Found'
    
    def find_all(self):
        for num, i in enumerate(self.comp_names[self.position::], start= self.position + 1):

            try:
                cookie_button = '//*[@id="didomi-notice-agree-button"]'
                cookie_btn_cl = driver.find_element_by_xpath(cookie_button).click()
                
            except NoSuchElementException:
                pass
            
            search_box = '//*[@id="input_search"]'
            search_box_query = WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.XPATH, search_box)))
            time.sleep(2)
            search_box_query.send_keys(i)
            search_box_query.submit()
               
            try:
                link_path = '//*[@id="search"]/div[1]/a'
                link_click = WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.XPATH, link_path)))
                link_click.click()  
        
            except(NoSuchElementException, TimeoutException, UnexpectedAlertPresentException): 
               self.siret.append('Not found')
               self.tva.append('Not found')
               self.naf.append('Not found')
               self.emp.append('Not found')
               self.chif.append('Not found')
               continue
            
               # WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.XPATH, '//*[@id="siret_number"]/span')))    
            self.siret.append(self.find_field(driver, '//*[@id="siret_number"]/span'))
            self.tva.append(self.find_field(driver,'//*[@id="tva_number"]/span'))
            self.naf.append(self.find_field(driver, '//*[@id="ape-histo-description"]'))
            self.emp.append(self.find_field(driver, '//*[@id="trancheeff-histo-description"]'))
            self.chif.append(self.find_field(driver, '//*[@id="rensjur"]/tbody/tr[22]/td[2]/span')) 
            print("{}:{}".format(num,i))
            self.position += 1
            time.sleep(3)
            
    def write_to_file(self, file_path): 
       
        df = pd.DataFrame( 
        
            {'Legal Company Name': self.comp_names,
              'SIRET': self.siret, 
              'TVA': self.tva,
              'NAF': self.naf,
              'Number of Employees': self.emp,
              'Chiffre d\'affaires': self.chif
              })
        
        df.to_excel(file_path) 

#------------------------------------------------------------------------------------------------------------------------

file = r'C:\Users\WL-133\Desktop\Comp_names.xlsx'
df = pd.read_excel(file)
comp_names = df['Name'].astype(str).to_list()

if os.path.exists('pickle_rick.pickle'):
    pickle_rick = pickle.load(open('pickle_rick.pickle', 'rb'))
else:
    pickle_rick = PickleRick(comp_names)

try:
    pickle_rick.find_all()
    pickle_rick.write_to_file(r'C:\Users\WL-133\Desktop\RECUP\Pt_1.xlsx')

except Exception as e:
    print(e)
    pickle.dump(pickle_rick, open('pickle_rick.pickle', 'wb'))
    
executionTime = (time.time() - startTime)
print('Execution time in seconds: ' + str(executionTime))
