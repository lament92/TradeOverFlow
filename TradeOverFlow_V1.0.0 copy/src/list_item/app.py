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
        seller_id = body.get('seller_id')
        min_price = body.get('min_price')

        if not all([item_type, seller_id, min_price]):
            return {'statusCode': 400, 'body': json.dumps({'message': 'Missing required fields'})}

        item_id = str(uuid.uuid4())
        timestamp = int(time.time())

        item = {
            'PK': f'ITEM_TYPE#{item_type}',
            'SK': f'SELL#{min_price}#CREATED#{timestamp}#ITEM#{item_id}',
            'item_id': item_id,
            'item_type': item_type,
            'seller_id': seller_id,
            'price': min_price,
            'status': 'LISTED',
            'created_at': timestamp
        }

        table.put_item(Item=item)

        # transform the item format for the response
        response_item = {
            "item_id": item["item_id"],
            "item_type": item["item_type"],
            "seller_id": item["seller_id"],
            "min_price": float(item["price"]), # JSON-friendly float
            "status": item["status"],
            "created_at": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(item["created_at"]))
        }

        return {
            'statusCode': 201,
            'body': json.dumps(response_item)
        }
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}