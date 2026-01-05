// @ts-nocheck
import { buildASTSchema } from "graphql";

const schemaAST = {
  kind: "Document",
  definitions: [
    {
      kind: "SchemaDefinition",
      operationTypes: [
        {
          kind: "OperationTypeDefinition",
          operation: "query",
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Query",
            },
          },
        },
        {
          kind: "OperationTypeDefinition",
          operation: "subscription",
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Subscription",
            },
          },
        },
      ],
      directives: [],
    },
    {
      kind: "DirectiveDefinition",
      description: {
        kind: "StringValue",
        value:
          "Marks the GraphQL type as indexable entity.  Each type that should be an entity is required to be annotated with this directive.",
        block: true,
      },
      name: {
        kind: "Name",
        value: "entity",
      },
      arguments: [],
      repeatable: false,
      locations: [
        {
          kind: "Name",
          value: "OBJECT",
        },
      ],
    },
    {
      kind: "DirectiveDefinition",
      description: {
        kind: "StringValue",
        value: "Defined a Subgraph ID for an object type",
        block: true,
      },
      name: {
        kind: "Name",
        value: "subgraphId",
      },
      arguments: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "String",
              },
            },
          },
          directives: [],
        },
      ],
      repeatable: false,
      locations: [
        {
          kind: "Name",
          value: "OBJECT",
        },
      ],
    },
    {
      kind: "DirectiveDefinition",
      description: {
        kind: "StringValue",
        value:
          "creates a virtual field on the entity that may be queried but cannot be set manually through the mappings API.",
        block: true,
      },
      name: {
        kind: "Name",
        value: "derivedFrom",
      },
      arguments: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "field",
          },
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "String",
              },
            },
          },
          directives: [],
        },
      ],
      repeatable: false,
      locations: [
        {
          kind: "Name",
          value: "FIELD_DEFINITION",
        },
      ],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "Aggregation_interval",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "hour",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "day",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ScalarTypeDefinition",
      name: {
        kind: "Name",
        value: "BigDecimal",
      },
      directives: [],
    },
    {
      kind: "ScalarTypeDefinition",
      name: {
        kind: "Name",
        value: "BigInt",
      },
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "BlockChangedFilter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "number_gte",
          },
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Int",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Block_height",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "hash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "number",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "number_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ScalarTypeDefinition",
      name: {
        kind: "Name",
        value: "Bytes",
      },
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "CollateralLock",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "CollateralLock_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "CollateralLock_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "CollateralLock_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "CollateralLock_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ScalarTypeDefinition",
      description: {
        kind: "StringValue",
        value: "8 bytes signed integer\n",
        block: true,
      },
      name: {
        kind: "Name",
        value: "Int8",
      },
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Listing",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "seller",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "expiresAt",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Boolean",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "createdAt",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Listing_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "seller_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "amount_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Boolean",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Boolean",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Boolean",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Boolean",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Listing_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Listing_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "Listing_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "seller",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "amount",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "pricePerToken",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "expiresAt",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "buyerPaysFee",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "createdAt",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "MarketplaceContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "MarketplaceContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "MarketplaceContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "MarketplaceContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "MarketplaceContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "MockUSDCContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "MockUSDCContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "MockUSDCContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "MockUSDCContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "MockUSDCContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      description: {
        kind: "StringValue",
        value: "Defines the order direction, either ascending or descending",
        block: true,
      },
      name: {
        kind: "Name",
        value: "OrderDirection",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "asc",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "desc",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Partner",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "name",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "String",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "PartnerManagerContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "PartnerManagerContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "PartnerManagerContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "PartnerManagerContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "PartnerManagerContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Partner_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "name_not_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Partner_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Partner_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "Partner_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "name",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "authorizedAt",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Query",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "mockUSDCContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "MockUSDCContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "mockUSDCContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MockUSDCContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MockUSDCContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "MockUSDCContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transfer",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Transfer",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transfers",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Transfer_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Transfer_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Transfer",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokensContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RoboshareTokensContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokensContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareTokensContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareTokensContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RoboshareTokensContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareToken",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RoboshareToken",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokens",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareToken_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareToken_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RoboshareToken",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transferSingleEvent",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "TransferSingleEvent",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transferSingleEvents",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TransferSingleEvent_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TransferSingleEvent_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "TransferSingleEvent",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partnerManagerContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "PartnerManagerContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partnerManagerContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "PartnerManagerContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "PartnerManagerContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "PartnerManagerContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Partner",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partners",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Partner_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Partner_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Partner",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registryRouterContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RegistryRouterContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registryRouterContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegistryRouterContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegistryRouterContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RegistryRouterContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registeredAssetRouter",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RegisteredAssetRouter",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registeredAssetRouters",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegisteredAssetRouter_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegisteredAssetRouter_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RegisteredAssetRouter",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicleRegistryContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "VehicleRegistryContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicleRegistryContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "VehicleRegistryContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "VehicleRegistryContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "VehicleRegistryContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicle",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Vehicle",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicles",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Vehicle_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Vehicle_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Vehicle",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "treasuryContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "TreasuryContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "treasuryContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TreasuryContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TreasuryContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "TreasuryContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "collateralLock",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "CollateralLock",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "collateralLocks",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "CollateralLock_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "CollateralLock_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "CollateralLock",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "marketplaceContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "MarketplaceContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "marketplaceContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MarketplaceContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MarketplaceContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "MarketplaceContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "listing",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Listing",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "listings",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Listing_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Listing_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Listing",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "Access to subgraph metadata",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_meta",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "_Meta_",
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RegisteredAssetRouter",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "owner",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "status",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Int",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RegisteredAssetRouter_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "assetId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "owner_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "status_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RegisteredAssetRouter_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RegisteredAssetRouter_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "RegisteredAssetRouter_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "assetId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "owner",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "status",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RegistryRouterContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RegistryRouterContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RegistryRouterContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RegistryRouterContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "RegistryRouterContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareToken",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "price",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "supply",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "maturityDate",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareToken_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "price_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "supply_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RoboshareToken_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RoboshareToken_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareToken_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "revenueTokenId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "price",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "supply",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "maturityDate",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "setAtBlock",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareTokensContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareTokensContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RoboshareTokensContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "RoboshareTokensContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "RoboshareTokensContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Subscription",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "mockUSDCContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "MockUSDCContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "mockUSDCContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MockUSDCContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MockUSDCContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "MockUSDCContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transfer",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Transfer",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transfers",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Transfer_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Transfer_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Transfer",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokensContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RoboshareTokensContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokensContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareTokensContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareTokensContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RoboshareTokensContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareToken",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RoboshareToken",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "roboshareTokens",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareToken_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RoboshareToken_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RoboshareToken",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transferSingleEvent",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "TransferSingleEvent",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transferSingleEvents",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TransferSingleEvent_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TransferSingleEvent_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "TransferSingleEvent",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partnerManagerContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "PartnerManagerContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partnerManagerContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "PartnerManagerContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "PartnerManagerContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "PartnerManagerContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Partner",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partners",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Partner_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Partner_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Partner",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registryRouterContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RegistryRouterContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registryRouterContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegistryRouterContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegistryRouterContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RegistryRouterContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registeredAssetRouter",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "RegisteredAssetRouter",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "registeredAssetRouters",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegisteredAssetRouter_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "RegisteredAssetRouter_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "RegisteredAssetRouter",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicleRegistryContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "VehicleRegistryContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicleRegistryContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "VehicleRegistryContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "VehicleRegistryContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "VehicleRegistryContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicle",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Vehicle",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vehicles",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Vehicle_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Vehicle_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Vehicle",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "treasuryContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "TreasuryContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "treasuryContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TreasuryContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "TreasuryContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "TreasuryContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "collateralLock",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "CollateralLock",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "collateralLocks",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "CollateralLock_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "CollateralLock_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "CollateralLock",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "marketplaceContract",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "MarketplaceContract",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "marketplaceContracts",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MarketplaceContract_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "MarketplaceContract_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "MarketplaceContract",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "listing",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "id",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "ID",
                  },
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Listing",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "listings",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "skip",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "0",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "first",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Int",
                },
              },
              defaultValue: {
                kind: "IntValue",
                value: "100",
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderBy",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Listing_orderBy",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "orderDirection",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "OrderDirection",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "where",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Listing_filter",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value:
                  "The block at which the query should be executed. Can either be a `{ hash: Bytes }` value containing a block hash, a `{ number: Int }` containing the block number, or a `{ number_gte: Int }` containing the minimum block number. In the case of `number_gte`, the query will be executed on the latest block only if the subgraph has progressed to or past the minimum block number. Defaults to the latest block when omitted.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
            {
              kind: "InputValueDefinition",
              description: {
                kind: "StringValue",
                value: "Set to `allow` to receive data even if the subgraph has skipped over errors while syncing.",
                block: true,
              },
              name: {
                kind: "Name",
                value: "subgraphError",
              },
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "_SubgraphErrorPolicy_",
                  },
                },
              },
              defaultValue: {
                kind: "EnumValue",
                value: "deny",
              },
              directives: [],
            },
          ],
          type: {
            kind: "NonNullType",
            type: {
              kind: "ListType",
              type: {
                kind: "NonNullType",
                type: {
                  kind: "NamedType",
                  name: {
                    kind: "Name",
                    value: "Listing",
                  },
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "Access to subgraph metadata",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_meta",
          },
          arguments: [
            {
              kind: "InputValueDefinition",
              name: {
                kind: "Name",
                value: "block",
              },
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Block_height",
                },
              },
              directives: [],
            },
          ],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "_Meta_",
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ScalarTypeDefinition",
      description: {
        kind: "StringValue",
        value: "A string representation of microseconds UNIX timestamp (16 digits)\n",
        block: true,
      },
      name: {
        kind: "Name",
        value: "Timestamp",
      },
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Transfer",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "TransferSingleEvent",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "operator",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "TransferSingleEvent_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "operator_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "TransferSingleEvent_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "TransferSingleEvent_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "TransferSingleEvent_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "operator",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "tokenId",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Transfer_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "from_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "to_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "value_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Transfer_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Transfer_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "Transfer_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "from",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "to",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "value",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "TreasuryContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "TreasuryContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "TreasuryContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "TreasuryContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "TreasuryContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Vehicle",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "vin",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "String",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "make",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "model",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "year",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "metadataURI",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "BigInt",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "VehicleRegistryContract",
      },
      fields: [
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "ID",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Bytes",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "VehicleRegistryContract_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "address_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "VehicleRegistryContract_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "VehicleRegistryContract_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "VehicleRegistryContract_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "address",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "InputObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "Vehicle_filter",
      },
      fields: [
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "ID",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "id_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "ID",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "partner_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "vin_not_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "make_not_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "model_not_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "year_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "String",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_contains_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_starts_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_starts_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_ends_with",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI_not_ends_with_nocase",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "String",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BigInt",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "BigInt",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lt",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_gte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_lte",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_in",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NonNullType",
              type: {
                kind: "NamedType",
                name: {
                  kind: "Name",
                  value: "Bytes",
                },
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash_not_contains",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          description: {
            kind: "StringValue",
            value: "Filter for the block changed event.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "_change_block",
          },
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "BlockChangedFilter",
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "and",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Vehicle_filter",
              },
            },
          },
          directives: [],
        },
        {
          kind: "InputValueDefinition",
          name: {
            kind: "Name",
            value: "or",
          },
          type: {
            kind: "ListType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Vehicle_filter",
              },
            },
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "Vehicle_orderBy",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "id",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "partner",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "vin",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "make",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "model",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "year",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "metadataURI",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockNumber",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "blockTimestamp",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          name: {
            kind: "Name",
            value: "transactionHash",
          },
          directives: [],
        },
      ],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      name: {
        kind: "Name",
        value: "_Block_",
      },
      fields: [
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "The hash of the block",
            block: true,
          },
          name: {
            kind: "Name",
            value: "hash",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "The block number",
            block: true,
          },
          name: {
            kind: "Name",
            value: "number",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Int",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "Integer representation of the timestamp stored in blocks for the chain",
            block: true,
          },
          name: {
            kind: "Name",
            value: "timestamp",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Int",
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "The hash of the parent block",
            block: true,
          },
          name: {
            kind: "Name",
            value: "parentHash",
          },
          arguments: [],
          type: {
            kind: "NamedType",
            name: {
              kind: "Name",
              value: "Bytes",
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "ObjectTypeDefinition",
      description: {
        kind: "StringValue",
        value: "The type for the top-level _meta field",
        block: true,
      },
      name: {
        kind: "Name",
        value: "_Meta_",
      },
      fields: [
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value:
              "Information about a specific subgraph block. The hash of the block\nwill be null if the _meta field has a block constraint that asks for\na block number. It will be filled if the _meta field has no block constraint\nand therefore asks for the latest  block\n",
            block: true,
          },
          name: {
            kind: "Name",
            value: "block",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "_Block_",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "The deployment ID",
            block: true,
          },
          name: {
            kind: "Name",
            value: "deployment",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "String",
              },
            },
          },
          directives: [],
        },
        {
          kind: "FieldDefinition",
          description: {
            kind: "StringValue",
            value: "If `true`, the subgraph encountered indexing errors at some past block",
            block: true,
          },
          name: {
            kind: "Name",
            value: "hasIndexingErrors",
          },
          arguments: [],
          type: {
            kind: "NonNullType",
            type: {
              kind: "NamedType",
              name: {
                kind: "Name",
                value: "Boolean",
              },
            },
          },
          directives: [],
        },
      ],
      interfaces: [],
      directives: [],
    },
    {
      kind: "EnumTypeDefinition",
      name: {
        kind: "Name",
        value: "_SubgraphErrorPolicy_",
      },
      values: [
        {
          kind: "EnumValueDefinition",
          description: {
            kind: "StringValue",
            value: "Data will be returned even if the subgraph has indexing errors",
            block: true,
          },
          name: {
            kind: "Name",
            value: "allow",
          },
          directives: [],
        },
        {
          kind: "EnumValueDefinition",
          description: {
            kind: "StringValue",
            value: "If the subgraph has indexing errors, data will be omitted. The default.",
            block: true,
          },
          name: {
            kind: "Name",
            value: "deny",
          },
          directives: [],
        },
      ],
      directives: [],
    },
  ],
};

export default buildASTSchema(schemaAST, {
  assumeValid: true,
  assumeValidSDL: true,
});
