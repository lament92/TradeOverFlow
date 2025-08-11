import json
import os
import boto3
from decimal import Decimal
import time

TABLE_NAME = os.environ['TABLE_NAME']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

# Helper to convert DynamoDB's Decimal to JSON-friendly float/int
def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError ("Type %s not serializable" % type(obj))

def handler(event, context):
    try:
        item_id = event['pathParameters']['itemId']
        
        # Query the Global Secondary Index to find the item by its ID
        response = table.query(
            IndexName='ItemIdIndex',
            KeyConditionExpression='item_id = :id',
            ExpressionAttributeValues={':id': item_id}
        )

        if not response.get('Items'):
            return {
                'statusCode': 404,
                'body': json.dumps({'message': f'Item with ID {item_id} not found'})
            }

        item = response['Items'][0]

        # Format the response according to the ItemStatus schema in openapi.yaml
        status_response = {
            "item_id": item.get("item_id"),
            "status": item.get("status")
        }

        # If the item is sold, add the extra fields
        if item.get("status") == "SOLD":
            status_response["sale_price"] = item.get("sale_price")
            status_response["sale_date"] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(item.get("sale_date")))
            status_response["buyer_id"] = item.get("buyer_id")
            
        return {
            'statusCode': 200,
            'body': json.dumps(status_response, default=json_serial)
        }

    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}