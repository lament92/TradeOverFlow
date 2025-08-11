import json
import os
import uuid
import boto3
from decimal import Decimal
import time

TABLE_NAME = os.environ['TABLE_NAME']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'), parse_float=Decimal)
        item_type = body.get('item_type')
        buyer_id = body.get('buyer_id')
        max_price = body.get('max_price')

        if not all([item_type, buyer_id, max_price]):
            return {'statusCode': 400, 'body': json.dumps({'message': 'Missing required fields'})}

        bid_id = str(uuid.uuid4())
        timestamp = int(time.time())

        bid = {
            'PK': f'ITEM_TYPE#{item_type}',
            'SK': f'BID#{max_price}#CREATED#{timestamp}#BID#{bid_id}', # Bids are sorted descending by price
            'bid_id': bid_id,
            'item_type': item_type,
            'buyer_id': buyer_id,
            'price': max_price,
            'status': 'PENDING',
            'created_at': timestamp
        }
        
        table.put_item(Item=bid)
        
        response_bid = {
            "bid_id": bid["bid_id"],
            "item_type": bid["item_type"],
            "buyer_id": bid["buyer_id"],
            "max_price": float(bid["price"]),
            "status": bid["status"],
            "created_at": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(bid["created_at"]))
        }

        return {
            'statusCode': 201,
            'body': json.dumps(response_bid)
        }
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}