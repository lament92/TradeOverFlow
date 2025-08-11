# Using Amazon DynamoDB with a Single-Table Design Pattern

**Status**: Accepted

## Context

The system needs to store multiple types of data—Items, Bids, and Transactions—and allow efficient querying across them. In particular, the matching engine must quickly retrieve all listings and bids under the same item category. Although a relational database like RDS could support this, it may struggle with scalability and performance under massive concurrent read/write conditions (e.g., Black Friday levels of traffic).

NoSQL was a better fit for the use case, but I needed to carefully choose the data modeling strategy.

## Decision

I decided to use Amazon DynamoDB as the primary database and adopt a **single-table design** pattern. All entities—Items, Bids, and Transactions—are stored in a single table named `tradeoverflow`. Partition keys (PK) and sort keys (SK) are used strategically to organize and relate different data types.

For example, all data related to a given item type (e.g., the item itself and its associated bids) are grouped under the same partition key:  
`PK = ITEM_TYPE#{item_type}`

This allows efficient querying of heterogeneous records in a single access pattern.

## Consequences

### Pros

- **High Performance and Scalability**: The single-table model enables efficient querying of related data using one Query operation, reducing database round-trips and maintaining low latency even at scale.

- **Cost Efficiency**: By minimizing the number of database calls, the solution reduces overall read/write costs on DynamoDB.

- **Flexible Query Support**: With carefully designed global secondary indexes (GSIs), I can support a variety of access patterns such as querying by `item_id` or fetching all active trading groups.

### Cons

- **Steep Learning Curve**: Single-table design is significantly different from relational modeling and requires a deeper understanding of DynamoDB best practices.

- **Lower Data Readability**: In the AWS Console, all entity types appear mixed in one table, making the data harder to interpret compared to multi-table designs.

- **Reduced Flexibility**: Once the data model is finalized, introducing entirely new access patterns might require complex migrations or the creation of new GSIs.