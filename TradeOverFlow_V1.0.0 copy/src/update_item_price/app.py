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
        item_id = event['pathParameters']['itemId']
        body = json.loads(event.get('body', '{}'), parse_float=Decimal)
        new_price = body.get('new_price')

        if not new_price:
            return {'statusCode': 400, 'body': json.dumps({'message': 'Missing required field: new_price'})}

        # 使用 client API 查询 GSI
        response = client.query(
            TableName=TABLE_NAME,
            IndexName='ItemIdIndex',
            KeyConditionExpression='item_id = :id',
            ExpressionAttributeValues={':id': {'S': item_id}}
        )

        if not response.get('Items'):
            return {'statusCode': 404, 'body': json.dumps({'message': f'Item with ID {item_id} not found'})}

        # 反序列化
        item = {k: v.get('S', v.get('N')) for k, v in response['Items'][0].items()}
        item['price'] = Decimal(item['price'])
        item['created_at'] = int(Decimal(item['created_at']))

        if item.get('status') == 'SOLD':
            return {
                'statusCode': 409,
                'body': json.dumps({'message': 'Cannot change the price of an item that has already been sold.'})
            }
        
        # 修正 SK 的拼写错误
        new_item_sk = f"SELL#{new_price}#CREATED#{item['created_at']}#ITEM#{item_id}"
        
        # 准备事务
        transact_items = [
            {'Delete': {'TableName': TABLE_NAME, 'Key': {'PK': {'S': item['PK']}, 'SK': {'S': item['SK']}}}},
            {'Put': {'TableName': TABLE_NAME, 'Item': {
                'PK': {'S': item['PK']}, 'SK': {'S': new_item_sk}, 'item_id': {'S': item_id},
                'item_type': {'S': item['item_type']}, 'seller_id': {'S': item['seller_id']},
                'price': {'N': str(new_price)}, 'status': {'S': 'LISTED'},
                'created_at': {'N': str(item['created_at'])}
            }}}
        ]
        
        client.transact_write_items(TransactItems=transact_items)
        
        response_item = {
            "item_id": item_id, "item_type": item['item_type'], "seller_id": item['seller_id'],
            "min_price": float(new_price), "status": "LISTED",
            "created_at": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(item["created_at"]))
        }

        return {'statusCode': 200, 'body': json.dumps(response_item)}
        
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps({'message': 'Internal Server Error'})}