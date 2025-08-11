import json
import os
import boto3
from decimal import Decimal
import time

TABLE_NAME = os.environ['TABLE_NAME']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError ("Type %s not serializable" % type(obj))

def handler(event, context):
    try:
        bid_id = event['pathParameters']['bidId']
        
        response = table.query(
            IndexName='BidIdIndex',
            KeyConditionExpression='bid_id = :id',
            ExpressionAttributeValues={':id': bid_id}
        )

        if not response.get('Items'):
            return {
                'statusCode': 404,
                'body': json.dumps({'message': f'Bid with ID {bid_id} not found'})
            }

        bid = response['Items'][0]

        status_response = {
            "bid_id": bid.get("bid_id"),
            "status": bid.get("status")
        }

        if bid.get("status") == "SUCCESSFUL":
            status_response["purchase_price"] = bid.get("purchase_price")
            status_response["purchase_date"] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(bid.get("purchase_date")))
            status_response["seller_id"] = bid.get("seller_id")
            
        return {
            'statusCode': 200,
            'body': json.dumps(status_response, default=json_serial)
        }

    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}