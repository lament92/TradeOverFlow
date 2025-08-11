# Choosing a Serverless Architecture Based on AWS Lambda

**Status**: Accepted

## Context

The project requires building a dynamic trading platform with high availability (99.99%), high scalability (capable of handling hourly traffic ranging from hundreds to millions), and ease of maintenance. Traditional server-based architectures such as EC2 demand complex capacity planning, server management, patching, and manual scaling, which increase operational overhead and make it difficult to respond efficiently to traffic surges.

Given these requirements, I needed an architecture that could natively fulfill the non-functional constraints without introducing unnecessary operational burden.

## Decision

I chose to adopt a fully serverless architecture, leveraging managed services provided by AWS. The key components are:

- **Compute**: AWS Lambda  
- **API Gateway**: Amazon API Gateway  
- **Database**: Amazon DynamoDB  
- **Background Scheduling**: Amazon EventBridge

All business logic is encapsulated within independent Lambda functions triggered either by HTTP requests through API Gateway or scheduled events via EventBridge.

## Consequences

### Pros

- **Scalability**: Both Lambda and DynamoDB scale automatically based on demand, allowing the system to elastically handle fluctuating traffic without manual intervention.
  
- **Availability**: By using AWS-managed services, I benefit from built-in high availability across multiple Availability Zones, supporting the 99.99% uptime goal.

- **Maintainability**: Each Lambda function operates as an independent microservice. This modularity enables independent development, deployment, and updates, improving maintainability and development velocity.

- **Cost Efficiency**: The pay-per-use pricing model ensures that the system incurs almost no cost during idle periods, which aligns with the requirement for cost-effective scalability.

- **Reduced Operational Overhead**: Since there are no servers or operating systems to manage, I could focus purely on implementing business logic rather than infrastructure.

### Cons

- **Cold Starts**: Lambda functions may experience latency during cold starts, particularly after periods of inactivity. This could affect operations sensitive to response time.

- **Vendor Lock-in**: The system becomes tightly coupled to AWS-specific serverless services, making future migrations to other cloud providers or on-premises environments more complex and costly.

- **Local Testing Complexity**: Emulating a complete serverless environment locally requires additional tools like the AWS SAM CLI and Docker, which introduces more complexity compared to traditional development setups.