import json
import os
import boto3
from decimal import Decimal
import time
from itertools import groupby

TABLE_NAME = os.environ['TABLE_NAME']
# using a boto3 client to interact with DynamoDB
if os.environ.get("AWS_SAM_LOCAL"):
    client = boto3.client('dynamodb', endpoint_url="http://dynamodb-local:8000")
else:
    client = boto3.client('dynamodb')

def deserialize_item(item):
    """Transform DynamoDB item format to a more Pythonic dict"""
    deserialized = {}
    for key, value in item.items():
        if 'S' in value:
            deserialized[key] = value['S']
        elif 'N' in value:
            deserialized[key] = Decimal(value['N'])
    return deserialized

def find_active_trading_sets():
    """using a paginator to find all active trading sets"""
    active_types = set()
    
    # Find all active item types by querying the StatusTypeIndex
    for status in ['LISTED', 'PENDING']:
        paginator = client.get_paginator('query')
        pages = paginator.paginate(
            TableName=TABLE_NAME,
            IndexName='StatusTypeIndex', # using a GSI to filter by status
            KeyConditionExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': {'S': status}}
        )
        for page in pages:
            for item in page.get('Items', []):
                deserialized = deserialize_item(item)
                active_types.add(deserialized.get('item_type'))
    
    print(f"Found active trading sets: {list(active_types)}")
    return list(active_types)

def handler(event, context):
    print("Starting trade processing cycle.")
    
    # Dynamically find all active item types
    active_item_types = find_active_trading_sets()
    
    for item_type in active_item_types:
        print(f"--- Processing trades for item type: {item_type} ---")
        try:
            paginator = client.get_paginator('query')
            pages = paginator.paginate(
                TableName=TABLE_NAME,
                KeyConditionExpression='PK = :pk',
                ExpressionAttributeValues={':pk': {'S': f'ITEM_TYPE#{item_type}'}}
            )
            items = []
            for page in pages:
                items.extend(page.get('Items', []))

            deserialized_items = [deserialize_item(i) for i in items]
            
            bids = sorted([i for i in deserialized_items if i['SK'].startswith('BID#') and i.get('status') == 'PENDING'], key=lambda x: x['price'], reverse=True)
            sells = sorted([i for i in deserialized_items if i['SK'].startswith('SELL#') and i.get('status') == 'LISTED'], key=lambda x: x['price'])

            if not bids or not sells:
                print(f"No matchable bids or listings for {item_type}. Skipping.")
                continue

            purchase_groups = [list(g) for k, g in groupby(bids, key=lambda x: x['price'])]

            while purchase_groups and sells:
                active_purchase_group = purchase_groups[0]
                active_purchase_price = active_purchase_group[0]['price']
                
                # Find eligible sells for the current purchase group
                eligible_sells = [s for s in sells if s['price'] <= active_purchase_price]
                if not eligible_sells:
                    purchase_groups.pop(0)
                    continue

                # Full purchase group and eligible sells
                buyers_to_satisfy = sorted(active_purchase_group, key=lambda x: x['created_at'])
                sellers_available = sorted(eligible_sells, key=lambda x: x['price'])
                
                transactions = []
                trade_time = int(time.time())

                while buyers_to_satisfy and sellers_available:
                    buyer = buyers_to_satisfy[0]
                    seller = sellers_available[0]

                    # Determine the sale price based on supply and demand
                    if len(buyers_to_satisfy) > len(sellers_available):
                        sale_price = seller['price'] # Requirement: supply is less than demand, use seller's price
                    else:
                        sale_price = buyer['price'] # Supply is more than demand, use buyer's price

                    print(f"Match: Buyer ({buyer['buyer_id']}) buys from Seller ({seller['seller_id']}) for ${sale_price}")

                    # Prepare the transactions for DynamoDB
                    transactions.append({'Update': {
                        'TableName': TABLE_NAME, 'Key': {'PK': {'S': seller['PK']}, 'SK': {'S': seller['SK']}},
                        'UpdateExpression': 'SET #status = :sold, buyer_id = :buyer, sale_price = :price, sale_date = :date',
                        'ExpressionAttributeNames': {'#status': 'status'},
                        'ExpressionAttributeValues': {
                            ':sold': {'S': 'SOLD'}, ':buyer': {'S': buyer['buyer_id']},
                            ':price': {'N': str(sale_price)}, ':date': {'N': str(trade_time)}
                        }}})
                    transactions.append({'Update': {
                        'TableName': TABLE_NAME, 'Key': {'PK': {'S': buyer['PK']}, 'SK': {'S': buyer['SK']}},
                        'UpdateExpression': 'SET #status = :success, seller_id = :seller, purchase_price = :price, purchase_date = :date',
                        'ExpressionAttributeNames': {'#status': 'status'},
                        'ExpressionAttributeValues': {
                            ':success': {'S': 'SUCCESSFUL'}, ':seller': {'S': seller['seller_id']},
                            ':price': {'N': str(sale_price)}, ':date': {'N': str(trade_time)}
                        }}})
                    
                    # remove the processed buyer and seller from their respective lists
                    buyers_to_satisfy.pop(0)
                    sellers_available.pop(0)

                if transactions:
                    print(f"Committing {len(transactions)//2} trades to DynamoDB for {item_type}.")
                    # summit the transactions in batches
                    for i in range(0, len(transactions), 100):
                        client.transact_write_items(TransactItems=transactions[i:i+100])

 
                if not buyers_to_satisfy:
                    purchase_groups.pop(0)
                
    
                sells = [s for s in sells if s not in eligible_sells or s in sellers_available]

        except Exception as e:
            print(f"An error occurred while processing {item_type}: {e}")
       
            continue
            
    print("Trade processing cycle finished.")
    return {'status': 'Success'}
