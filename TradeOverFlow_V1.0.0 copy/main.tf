terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

# --- Variable for receiving a pre-existing role ARN ---
variable "lambda_execution_role_arn" {
  description = "The ARN of the pre-existing IAM role for Lambda execution in the Learner Lab."
  type        = string
}

variable "project_name" {
  description = "A unique name for the project to prefix resources."
  default     = "tradeoverflow"
}

# --------------------------------------------------------------
# 1. DynamoDB Table (WITH NEW GSI)
# --------------------------------------------------------------
resource "aws_dynamodb_table" "main" {
  name           = var.project_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "PK"
  range_key      = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "item_id"
    type = "S"
  }
  attribute {
    name = "bid_id"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "item_type"
    type = "S"
  }

  global_secondary_index {
    name            = "ItemIdIndex"
    hash_key        = "item_id"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "BidIdIndex"
    hash_key        = "bid_id"
    projection_type = "ALL"
  }
  # --- New GSI for finding active trade sets ---
  global_secondary_index {
    name            = "StatusTypeIndex"
    hash_key        = "status" # FOR EXAMPLE "LISTED" OR "PENDING"
    range_key       = "item_type"
    projection_type = "INCLUDE"
    non_key_attributes = ["item_type"]
  }
}


# --------------------------------------------------------------
# 2. IAM Role Section (DISPOSED)
# --------------------------------------------------------------

# --------------------------------------------------------------
# 3. Create ZIP archives for all 7 Lambda functions
# --------------------------------------------------------------
data "archive_file" "list_item" {
  type        = "zip"
  source_dir  = "${path.module}/src/list_item"
  output_path = "${path.module}/zips/list_item.zip"
}
data "archive_file" "get_item_status" {
  type        = "zip"
  source_dir  = "${path.module}/src/get_item_status"
  output_path = "${path.module}/zips/get_item_status.zip"
}
data "archive_file" "update_item_price" {
  type        = "zip"
  source_dir  = "${path.module}/src/update_item_price"
  output_path = "${path.module}/zips/update_item_price.zip"
}
data "archive_file" "submit_bid" {
  type        = "zip"
  source_dir  = "${path.module}/src/submit_bid"
  output_path = "${path.module}/zips/submit_bid.zip"
}
data "archive_file" "get_bid_status" {
  type        = "zip"
  source_dir  = "${path.module}/src/get_bid_status"
  output_path = "${path.module}/zips/get_bid_status.zip"
}
data "archive_file" "update_bid_price" {
  type        = "zip"
  source_dir  = "${path.module}/src/update_bid_price"
  output_path = "${path.module}/zips/update_bid_price.zip"
}
data "archive_file" "process_trades" {
  type        = "zip"
  source_dir  = "${path.module}/src/process_trades"
  output_path = "${path.module}/zips/process_trades.zip"
}

# --------------------------------------------------------------
# 4. All 7 Lambda function resources
# --------------------------------------------------------------
resource "aws_lambda_function" "list_item" {
  function_name    = "${var.project_name}-listItem"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.list_item.output_path
  source_code_hash = data.archive_file.list_item.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "get_item_status" {
  function_name    = "${var.project_name}-getItemStatus"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.get_item_status.output_path
  source_code_hash = data.archive_file.get_item_status.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "update_item_price" {
  function_name    = "${var.project_name}-updateItemPrice"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.update_item_price.output_path
  source_code_hash = data.archive_file.update_item_price.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "submit_bid" {
  function_name    = "${var.project_name}-submitBid"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.submit_bid.output_path
  source_code_hash = data.archive_file.submit_bid.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "get_bid_status" {
  function_name    = "${var.project_name}-getBidStatus"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.get_bid_status.output_path
  source_code_hash = data.archive_file.get_bid_status.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "update_bid_price" {
  function_name    = "${var.project_name}-updateBidPrice"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  filename         = data.archive_file.update_bid_price.output_path
  source_code_hash = data.archive_file.update_bid_price.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}
resource "aws_lambda_function" "process_trades" {
  function_name    = "${var.project_name}-processTrades"
  role             = var.lambda_execution_role_arn
  handler          = "app.handler"
  runtime          = "python3.9"
  timeout          = 60
  filename         = data.archive_file.process_trades.output_path
  source_code_hash = data.archive_file.process_trades.output_base64sha256
  environment { variables = { TABLE_NAME = aws_dynamodb_table.main.name } }
}


# --------------------------------------------------------------
# 5. API Gateway - COMPLETELY DEFINITION
# --------------------------------------------------------------
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "TradeOverflow API"
}

# --- /items Source ---
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "items"
}
resource "aws_api_gateway_method" "items_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "items_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.items_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_item.invoke_arn
}

# --- /items/{itemId} Source ---
resource "aws_api_gateway_resource" "items_item_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{itemId}"
}

# --- /items/{itemId}/status ---
resource "aws_api_gateway_resource" "items_item_id_status" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.items_item_id.id
  path_part   = "status"
}
resource "aws_api_gateway_method" "items_item_id_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items_item_id_status.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "items_item_id_status_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.items_item_id_status.id
  http_method             = aws_api_gateway_method.items_item_id_status_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_item_status.invoke_arn
}

# --- /items/{itemId}/price ---
resource "aws_api_gateway_resource" "items_item_id_price" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.items_item_id.id
  path_part   = "price"
}
resource "aws_api_gateway_method" "items_item_id_price_put" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items_item_id_price.id
  http_method   = "PUT"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "items_item_id_price_put_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.items_item_id_price.id
  http_method             = aws_api_gateway_method.items_item_id_price_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_item_price.invoke_arn
}

# --- /bids Source ---
resource "aws_api_gateway_resource" "bids" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "bids"
}
resource "aws_api_gateway_method" "bids_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.bids.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "bids_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.bids.id
  http_method             = aws_api_gateway_method.bids_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.submit_bid.invoke_arn
}

# --- /bids/{bidId} Source ---
resource "aws_api_gateway_resource" "bids_bid_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.bids.id
  path_part   = "{bidId}"
}

# --- /bids/{bidId}/status ---
resource "aws_api_gateway_resource" "bids_bid_id_status" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.bids_bid_id.id
  path_part   = "status"
}
resource "aws_api_gateway_method" "bids_bid_id_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.bids_bid_id_status.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "bids_bid_id_status_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.bids_bid_id_status.id
  http_method             = aws_api_gateway_method.bids_bid_id_status_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_bid_status.invoke_arn
}

# --- /bids/{bidId}/price ---
resource "aws_api_gateway_resource" "bids_bid_id_price" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.bids_bid_id.id
  path_part   = "price"
}
resource "aws_api_gateway_method" "bids_bid_id_price_put" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.bids_bid_id_price.id
  http_method   = "PUT"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "bids_bid_id_price_put_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.bids_bid_id_price.id
  http_method             = aws_api_gateway_method.bids_bid_id_price_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_bid_price.invoke_arn
}

# --------------------------------------------------------------
# 6. API Gateway Deployment and stage
# --------------------------------------------------------------
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.items_post_lambda.id,
      aws_api_gateway_integration.items_item_id_status_get_lambda.id,
      aws_api_gateway_integration.items_item_id_price_put_lambda.id,
      aws_api_gateway_integration.bids_post_lambda.id,
      aws_api_gateway_integration.bids_bid_id_status_get_lambda.id,
      aws_api_gateway_integration.bids_bid_id_price_put_lambda.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"
}

# --- newly add section: lambda permission ---
resource "aws_lambda_permission" "api_gw_list_item" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.items_post.http_method}${aws_api_gateway_resource.items.path}"
}
resource "aws_lambda_permission" "api_gw_get_item_status" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_item_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.items_item_id_status_get.http_method}${aws_api_gateway_resource.items_item_id_status.path}"
}
resource "aws_lambda_permission" "api_gw_update_item_price" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_item_price.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.items_item_id_price_put.http_method}${aws_api_gateway_resource.items_item_id_price.path}"
}
resource "aws_lambda_permission" "api_gw_submit_bid" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_bid.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.bids_post.http_method}${aws_api_gateway_resource.bids.path}"
}
resource "aws_lambda_permission" "api_gw_get_bid_status" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_bid_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.bids_bid_id_status_get.http_method}${aws_api_gateway_resource.bids_bid_id_status.path}"
}
resource "aws_lambda_permission" "api_gw_update_bid_price" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_bid_price.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.bids_bid_id_price_put.http_method}${aws_api_gateway_resource.bids_bid_id_price.path}"
}


# --------------------------------------------------------------
# 7. EventBridge Scheduler for continuous matching
# --------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "${var.project_name}-every-minute-trigger"
  description         = "Fires every minute to process trades"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "process_trades_lambda" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "ProcessTradesLambda"
  arn       = aws_lambda_function.process_trades.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_process_trades" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_trades.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}

# --------------------------------------------------------------
# 8. Output the API URL for scripts and testing.
# --------------------------------------------------------------
output "invoke_url" {
  description = "Base URL for the API stage"
  value       = aws_api_gateway_stage.prod.invoke_url
}
