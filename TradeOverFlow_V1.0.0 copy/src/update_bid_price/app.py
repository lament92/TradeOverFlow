import json
import os
import boto3
from decimal import Decimal
import time

TABLE_NAME = os.environ['TABLE_NAME']
# 根据环境配置 client
if os.environ.get("AWS_SAM_LOCAL"):
    client = boto3.client('dynamodb', endpoint_url="http://dynamodb-local:8000")
else:
    client = boto3.client('dynamodb')

def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError ("Type %s not serializable" % type(obj))

def handler(event, context):
    try:
        bid_id = event['pathParameters']['bidId']
        body = json.loads(event.get('body', '{}'), parse_float=Decimal)
        new_price = body.get('new_price')

        if not new_price:
            return {'statusCode': 400, 'body': json.dumps({'message': 'Missing required field: new_price'})}

        response = client.query(
            TableName=TABLE_NAME,
            IndexName='BidIdIndex',
            KeyConditionExpression='bid_id = :id',
            ExpressionAttributeValues={':id': {'S': bid_id}}
        )

        if not response.get('Items'):
            return {'statusCode': 404, 'body': json.dumps({'message': f'Bid with ID {bid_id} not found'})}

        bid = {k: v.get('S', v.get('N')) for k, v in response['Items'][0].items()}
        bid['price'] = Decimal(bid['price'])
        bid['created_at'] = int(Decimal(bid['created_at']))

        if bid.get('status') == 'SUCCESSFUL':
            return {
                'statusCode': 409,
                'body': json.dumps({'message': 'Cannot change the price of a bid that has already been fulfilled.'})
            }
        
        new_bid_sk = f"BID#{new_price}#CREATED#{bid['created_at']}#BID#{bid_id}"

        transact_items = [
            {'Delete': {'TableName': TABLE_NAME, 'Key': {'PK': {'S': bid['PK']}, 'SK': {'S': bid['SK']}}}},
            {'Put': {'TableName': TABLE_NAME, 'Item': {
                'PK': {'S': bid['PK']}, 'SK': {'S': new_bid_sk}, 'bid_id': {'S': bid_id},
                'item_type': {'S': bid['item_type']}, 'buyer_id': {'S': bid['buyer_id']},
                'price': {'N': str(new_price)}, 'status': {'S': 'PENDING'},
                'created_at': {'N': str(bid['created_at'])}
            }}}
        ]
        
        client.transact_write_items(TransactItems=transact_items)
        
        response_bid = {
            "bid_id": bid_id, "item_type": bid['item_type'], "buyer_id": bid['buyer_id'],
            "max_price": float(new_price), "status": "PENDING",
            "created_at": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(bid["created_at"]))
        }

        return {'statusCode': 200, 'body': json.dumps(response_bid)}
        
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}