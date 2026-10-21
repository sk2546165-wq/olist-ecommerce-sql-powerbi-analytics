import pandas as pd

df = pd.read_csv(
    r'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_order_reviews_dataset.csv'
)

print(len(df))  # note this number - compare against final SQL row count later

# Strip embedded newlines/carriage returns so every record is exactly one line
for col in ['review_comment_title', 'review_comment_message']:
    df[col] = df[col].astype(str).str.replace(r'[\r\n]+', ' ', regex=True)

df.to_csv(
    r'C:\Users\RAJESH\OneDrive\Desktop\Sumit\1_SQL & PowerBI_Self Made Project\04_Brazillian E-Commerce Dataset\olist_order_reviews_cleaned.csv',
    index=False,
    sep=',',
    quoting=1  # QUOTE_ALL — wraps every field in quotes, safest for BULK INSERT
)

print(len(df))
