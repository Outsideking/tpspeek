
def calculate_price(version:int, num_languages:int):
    base_price = 100.0
    lang_factor = 0.2 * num_languages
    # price grows with version tiers: version 1 is base, each higher tier multiplies base by (1 + lang_factor)
    multiplier = 1 + (version - 1) * lang_factor
    price_per_month = base_price * multiplier
    price_per_year = price_per_month * 12
    return round(price_per_month, 2), round(price_per_year, 2)
