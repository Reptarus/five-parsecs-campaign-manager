import urllib.request
import os

def download_font(url, filename):
    os.makedirs('assets/fonts', exist_ok=True)
    filepath = os.path.join('assets/fonts', filename)
    urllib.request.urlretrieve(url, filepath)
    print(f'Downloaded {filename}')

# Font URLs
anonymous_pro_url = "https://fonts.google.com/download?family=Anonymous+Pro"
courier_prime_url = "https://fonts.google.com/download?family=Courier+Prime"

# Download fonts
download_font(anonymous_pro_url, 'AnonymousPro-Regular.ttf')
download_font(courier_prime_url, 'CourierPrime-Regular.ttf') 