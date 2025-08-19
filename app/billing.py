def calculate_price(version:int, num_languages:int):
    base_price = 100
    lang_factor = 0.2 * num_languages
    price_per_month = base_price + (base_price * lang_factor * (version-1))
    price_per_year = price_per_month * 12
    return price_per_month, price_per_year
