// @ts-nocheck
import { GraphQLResolveInfo, SelectionSetNode, FieldNode, GraphQLScalarType, GraphQLScalarTypeConfig } from 'graphql';
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';
import { gql } from '@graphql-mesh/utils';

import type { GetMeshOptions } from '@graphql-mesh/runtime';
import type { YamlConfig } from '@graphql-mesh/types';
import { PubSub } from '@graphql-mesh/utils';
import { DefaultLogger } from '@graphql-mesh/utils';
import MeshCache from "@graphql-mesh/cache-localforage";
import { fetch as fetchFn } from '@whatwg-node/fetch';

import { MeshResolvedSource } from '@graphql-mesh/runtime';
import { MeshTransform, MeshPlugin } from '@graphql-mesh/types';
import GraphqlHandler from "@graphql-mesh/graphql"
import BareMerger from "@graphql-mesh/merger-bare";
import { printWithCache } from '@graphql-mesh/utils';
import { usePersistedOperations } from '@graphql-yoga/plugin-persisted-operations';
import { createMeshHTTPHandler, MeshHTTPHandler } from '@graphql-mesh/http';
import { getMesh, ExecuteMeshFn, SubscribeMeshFn, MeshContext as BaseMeshContext, MeshInstance } from '@graphql-mesh/runtime';
import { MeshStore, FsStoreStorageAdapter } from '@graphql-mesh/store';
import { path as pathModule } from '@graphql-mesh/cross-helpers';
import { ImportFn } from '@graphql-mesh/types';
import type { RoboshareProtocolTypes } from './sources/RoboshareProtocol/types';
import * as importedModule$0 from "./sources/RoboshareProtocol/introspectionSchema";
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
export type RequireFields<T, K extends keyof T> = Omit<T, K> & { [P in K]-?: NonNullable<T[P]> };



/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  BigDecimal: { input: any; output: any; }
  BigInt: { input: any; output: any; }
  Bytes: { input: any; output: any; }
  Int8: { input: any; output: any; }
  Timestamp: { input: any; output: any; }
};

export type Aggregation_interval =
  | 'hour'
  | 'day';

export type BlockChangedFilter = {
  number_gte: Scalars['Int']['input'];
};

export type Block_height = {
  hash?: InputMaybe<Scalars['Bytes']['input']>;
  number?: InputMaybe<Scalars['Int']['input']>;
  number_gte?: InputMaybe<Scalars['Int']['input']>;
};

export type CollateralLock = {
  id: Scalars['ID']['output'];
  assetId: Scalars['BigInt']['output'];
  partner: Scalars['Bytes']['output'];
  amount: Scalars['BigInt']['output'];
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type CollateralLock_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  assetId?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_not?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  assetId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  partner?: InputMaybe<Scalars['Bytes']['input']>;
  partner_not?: InputMaybe<Scalars['Bytes']['input']>;
  partner_gt?: InputMaybe<Scalars['Bytes']['input']>;
  partner_lt?: InputMaybe<Scalars['Bytes']['input']>;
  partner_gte?: InputMaybe<Scalars['Bytes']['input']>;
  partner_lte?: InputMaybe<Scalars['Bytes']['input']>;
  partner_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  partner_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  partner_contains?: InputMaybe<Scalars['Bytes']['input']>;
  partner_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  amount?: InputMaybe<Scalars['BigInt']['input']>;
  amount_not?: InputMaybe<Scalars['BigInt']['input']>;
  amount_gt?: InputMaybe<Scalars['BigInt']['input']>;
  amount_lt?: InputMaybe<Scalars['BigInt']['input']>;
  amount_gte?: InputMaybe<Scalars['BigInt']['input']>;
  amount_lte?: InputMaybe<Scalars['BigInt']['input']>;
  amount_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  amount_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<CollateralLock_filter>>>;
  or?: InputMaybe<Array<InputMaybe<CollateralLock_filter>>>;
};

export type CollateralLock_orderBy =
  | 'id'
  | 'assetId'
  | 'partner'
  | 'amount'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type Listing = {
  id: Scalars['ID']['output'];
  tokenId: Scalars['BigInt']['output'];
  assetId: Scalars['BigInt']['output'];
  seller: Scalars['Bytes']['output'];
  amount: Scalars['BigInt']['output'];
  pricePerToken: Scalars['BigInt']['output'];
  expiresAt: Scalars['BigInt']['output'];
  buyerPaysFee: Scalars['Boolean']['output'];
  createdAt: Scalars['BigInt']['output'];
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type Listing_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  tokenId?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_not?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  tokenId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  assetId?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_not?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  assetId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  seller?: InputMaybe<Scalars['Bytes']['input']>;
  seller_not?: InputMaybe<Scalars['Bytes']['input']>;
  seller_gt?: InputMaybe<Scalars['Bytes']['input']>;
  seller_lt?: InputMaybe<Scalars['Bytes']['input']>;
  seller_gte?: InputMaybe<Scalars['Bytes']['input']>;
  seller_lte?: InputMaybe<Scalars['Bytes']['input']>;
  seller_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  seller_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  seller_contains?: InputMaybe<Scalars['Bytes']['input']>;
  seller_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  amount?: InputMaybe<Scalars['BigInt']['input']>;
  amount_not?: InputMaybe<Scalars['BigInt']['input']>;
  amount_gt?: InputMaybe<Scalars['BigInt']['input']>;
  amount_lt?: InputMaybe<Scalars['BigInt']['input']>;
  amount_gte?: InputMaybe<Scalars['BigInt']['input']>;
  amount_lte?: InputMaybe<Scalars['BigInt']['input']>;
  amount_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  amount_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  pricePerToken?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_not?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_gt?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_lt?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_gte?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_lte?: InputMaybe<Scalars['BigInt']['input']>;
  pricePerToken_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  pricePerToken_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  expiresAt?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_not?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_gt?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_lt?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_gte?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_lte?: InputMaybe<Scalars['BigInt']['input']>;
  expiresAt_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  expiresAt_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  buyerPaysFee?: InputMaybe<Scalars['Boolean']['input']>;
  buyerPaysFee_not?: InputMaybe<Scalars['Boolean']['input']>;
  buyerPaysFee_in?: InputMaybe<Array<Scalars['Boolean']['input']>>;
  buyerPaysFee_not_in?: InputMaybe<Array<Scalars['Boolean']['input']>>;
  createdAt?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_not?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_gt?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_lt?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_gte?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_lte?: InputMaybe<Scalars['BigInt']['input']>;
  createdAt_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  createdAt_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<Listing_filter>>>;
  or?: InputMaybe<Array<InputMaybe<Listing_filter>>>;
};

export type Listing_orderBy =
  | 'id'
  | 'tokenId'
  | 'assetId'
  | 'seller'
  | 'amount'
  | 'pricePerToken'
  | 'expiresAt'
  | 'buyerPaysFee'
  | 'createdAt'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type MarketplaceContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type MarketplaceContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<MarketplaceContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<MarketplaceContract_filter>>>;
};

export type MarketplaceContract_orderBy =
  | 'id'
  | 'address';

export type MockUSDCContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type MockUSDCContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<MockUSDCContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<MockUSDCContract_filter>>>;
};

export type MockUSDCContract_orderBy =
  | 'id'
  | 'address';

/** Defines the order direction, either ascending or descending */
export type OrderDirection =
  | 'asc'
  | 'desc';

export type Partner = {
  id: Scalars['ID']['output'];
  name: Scalars['String']['output'];
  authorizedAt: Scalars['BigInt']['output'];
  address: Scalars['Bytes']['output'];
};

export type PartnerManagerContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type PartnerManagerContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<PartnerManagerContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<PartnerManagerContract_filter>>>;
};

export type PartnerManagerContract_orderBy =
  | 'id'
  | 'address';

export type Partner_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  name?: InputMaybe<Scalars['String']['input']>;
  name_not?: InputMaybe<Scalars['String']['input']>;
  name_gt?: InputMaybe<Scalars['String']['input']>;
  name_lt?: InputMaybe<Scalars['String']['input']>;
  name_gte?: InputMaybe<Scalars['String']['input']>;
  name_lte?: InputMaybe<Scalars['String']['input']>;
  name_in?: InputMaybe<Array<Scalars['String']['input']>>;
  name_not_in?: InputMaybe<Array<Scalars['String']['input']>>;
  name_contains?: InputMaybe<Scalars['String']['input']>;
  name_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  name_not_contains?: InputMaybe<Scalars['String']['input']>;
  name_not_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  name_starts_with?: InputMaybe<Scalars['String']['input']>;
  name_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  name_not_starts_with?: InputMaybe<Scalars['String']['input']>;
  name_not_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  name_ends_with?: InputMaybe<Scalars['String']['input']>;
  name_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  name_not_ends_with?: InputMaybe<Scalars['String']['input']>;
  name_not_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  authorizedAt?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_not?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_gt?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_lt?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_gte?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_lte?: InputMaybe<Scalars['BigInt']['input']>;
  authorizedAt_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  authorizedAt_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<Partner_filter>>>;
  or?: InputMaybe<Array<InputMaybe<Partner_filter>>>;
};

export type Partner_orderBy =
  | 'id'
  | 'name'
  | 'authorizedAt'
  | 'address';

export type Query = {
  mockUSDCContract?: Maybe<MockUSDCContract>;
  mockUSDCContracts: Array<MockUSDCContract>;
  transfer?: Maybe<Transfer>;
  transfers: Array<Transfer>;
  roboshareTokensContract?: Maybe<RoboshareTokensContract>;
  roboshareTokensContracts: Array<RoboshareTokensContract>;
  roboshareToken?: Maybe<RoboshareToken>;
  roboshareTokens: Array<RoboshareToken>;
  transferSingleEvent?: Maybe<TransferSingleEvent>;
  transferSingleEvents: Array<TransferSingleEvent>;
  partnerManagerContract?: Maybe<PartnerManagerContract>;
  partnerManagerContracts: Array<PartnerManagerContract>;
  partner?: Maybe<Partner>;
  partners: Array<Partner>;
  registryRouterContract?: Maybe<RegistryRouterContract>;
  registryRouterContracts: Array<RegistryRouterContract>;
  registeredAssetRouter?: Maybe<RegisteredAssetRouter>;
  registeredAssetRouters: Array<RegisteredAssetRouter>;
  vehicleRegistryContract?: Maybe<VehicleRegistryContract>;
  vehicleRegistryContracts: Array<VehicleRegistryContract>;
  vehicle?: Maybe<Vehicle>;
  vehicles: Array<Vehicle>;
  treasuryContract?: Maybe<TreasuryContract>;
  treasuryContracts: Array<TreasuryContract>;
  collateralLock?: Maybe<CollateralLock>;
  collateralLocks: Array<CollateralLock>;
  marketplaceContract?: Maybe<MarketplaceContract>;
  marketplaceContracts: Array<MarketplaceContract>;
  listing?: Maybe<Listing>;
  listings: Array<Listing>;
  /** Access to subgraph metadata */
  _meta?: Maybe<_Meta_>;
};


export type QuerymockUSDCContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerymockUSDCContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<MockUSDCContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<MockUSDCContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytransferArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytransfersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Transfer_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Transfer_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryroboshareTokensContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryroboshareTokensContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RoboshareTokensContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RoboshareTokensContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryroboshareTokenArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryroboshareTokensArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RoboshareToken_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RoboshareToken_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytransferSingleEventArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytransferSingleEventsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<TransferSingleEvent_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<TransferSingleEvent_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerypartnerManagerContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerypartnerManagerContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<PartnerManagerContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<PartnerManagerContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerypartnerArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerypartnersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Partner_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Partner_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryregistryRouterContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryregistryRouterContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RegistryRouterContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RegistryRouterContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryregisteredAssetRouterArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryregisteredAssetRoutersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RegisteredAssetRouter_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RegisteredAssetRouter_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryvehicleRegistryContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryvehicleRegistryContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<VehicleRegistryContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<VehicleRegistryContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryvehicleArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QueryvehiclesArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Vehicle_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Vehicle_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytreasuryContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerytreasuryContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<TreasuryContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<TreasuryContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerycollateralLockArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerycollateralLocksArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<CollateralLock_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<CollateralLock_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerymarketplaceContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerymarketplaceContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<MarketplaceContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<MarketplaceContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerylistingArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type QuerylistingsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Listing_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Listing_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type Query_metaArgs = {
  block?: InputMaybe<Block_height>;
};

export type RegisteredAssetRouter = {
  id: Scalars['ID']['output'];
  assetId: Scalars['BigInt']['output'];
  owner: Scalars['Bytes']['output'];
  status: Scalars['Int']['output'];
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type RegisteredAssetRouter_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  assetId?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_not?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  assetId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  assetId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  owner?: InputMaybe<Scalars['Bytes']['input']>;
  owner_not?: InputMaybe<Scalars['Bytes']['input']>;
  owner_gt?: InputMaybe<Scalars['Bytes']['input']>;
  owner_lt?: InputMaybe<Scalars['Bytes']['input']>;
  owner_gte?: InputMaybe<Scalars['Bytes']['input']>;
  owner_lte?: InputMaybe<Scalars['Bytes']['input']>;
  owner_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  owner_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  owner_contains?: InputMaybe<Scalars['Bytes']['input']>;
  owner_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  status?: InputMaybe<Scalars['Int']['input']>;
  status_not?: InputMaybe<Scalars['Int']['input']>;
  status_gt?: InputMaybe<Scalars['Int']['input']>;
  status_lt?: InputMaybe<Scalars['Int']['input']>;
  status_gte?: InputMaybe<Scalars['Int']['input']>;
  status_lte?: InputMaybe<Scalars['Int']['input']>;
  status_in?: InputMaybe<Array<Scalars['Int']['input']>>;
  status_not_in?: InputMaybe<Array<Scalars['Int']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<RegisteredAssetRouter_filter>>>;
  or?: InputMaybe<Array<InputMaybe<RegisteredAssetRouter_filter>>>;
};

export type RegisteredAssetRouter_orderBy =
  | 'id'
  | 'assetId'
  | 'owner'
  | 'status'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type RegistryRouterContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type RegistryRouterContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<RegistryRouterContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<RegistryRouterContract_filter>>>;
};

export type RegistryRouterContract_orderBy =
  | 'id'
  | 'address';

export type RoboshareToken = {
  id: Scalars['ID']['output'];
  revenueTokenId: Scalars['BigInt']['output'];
  price: Scalars['BigInt']['output'];
  supply: Scalars['BigInt']['output'];
  maturityDate: Scalars['BigInt']['output'];
  setAtBlock: Scalars['BigInt']['output'];
};

export type RoboshareToken_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  revenueTokenId?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_not?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  revenueTokenId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  revenueTokenId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  price?: InputMaybe<Scalars['BigInt']['input']>;
  price_not?: InputMaybe<Scalars['BigInt']['input']>;
  price_gt?: InputMaybe<Scalars['BigInt']['input']>;
  price_lt?: InputMaybe<Scalars['BigInt']['input']>;
  price_gte?: InputMaybe<Scalars['BigInt']['input']>;
  price_lte?: InputMaybe<Scalars['BigInt']['input']>;
  price_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  price_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  supply?: InputMaybe<Scalars['BigInt']['input']>;
  supply_not?: InputMaybe<Scalars['BigInt']['input']>;
  supply_gt?: InputMaybe<Scalars['BigInt']['input']>;
  supply_lt?: InputMaybe<Scalars['BigInt']['input']>;
  supply_gte?: InputMaybe<Scalars['BigInt']['input']>;
  supply_lte?: InputMaybe<Scalars['BigInt']['input']>;
  supply_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  supply_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  maturityDate?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_not?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_gt?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_lt?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_gte?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_lte?: InputMaybe<Scalars['BigInt']['input']>;
  maturityDate_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  maturityDate_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  setAtBlock?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_not?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_gt?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_lt?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_gte?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_lte?: InputMaybe<Scalars['BigInt']['input']>;
  setAtBlock_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  setAtBlock_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<RoboshareToken_filter>>>;
  or?: InputMaybe<Array<InputMaybe<RoboshareToken_filter>>>;
};

export type RoboshareToken_orderBy =
  | 'id'
  | 'revenueTokenId'
  | 'price'
  | 'supply'
  | 'maturityDate'
  | 'setAtBlock';

export type RoboshareTokensContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type RoboshareTokensContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<RoboshareTokensContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<RoboshareTokensContract_filter>>>;
};

export type RoboshareTokensContract_orderBy =
  | 'id'
  | 'address';

export type Subscription = {
  mockUSDCContract?: Maybe<MockUSDCContract>;
  mockUSDCContracts: Array<MockUSDCContract>;
  transfer?: Maybe<Transfer>;
  transfers: Array<Transfer>;
  roboshareTokensContract?: Maybe<RoboshareTokensContract>;
  roboshareTokensContracts: Array<RoboshareTokensContract>;
  roboshareToken?: Maybe<RoboshareToken>;
  roboshareTokens: Array<RoboshareToken>;
  transferSingleEvent?: Maybe<TransferSingleEvent>;
  transferSingleEvents: Array<TransferSingleEvent>;
  partnerManagerContract?: Maybe<PartnerManagerContract>;
  partnerManagerContracts: Array<PartnerManagerContract>;
  partner?: Maybe<Partner>;
  partners: Array<Partner>;
  registryRouterContract?: Maybe<RegistryRouterContract>;
  registryRouterContracts: Array<RegistryRouterContract>;
  registeredAssetRouter?: Maybe<RegisteredAssetRouter>;
  registeredAssetRouters: Array<RegisteredAssetRouter>;
  vehicleRegistryContract?: Maybe<VehicleRegistryContract>;
  vehicleRegistryContracts: Array<VehicleRegistryContract>;
  vehicle?: Maybe<Vehicle>;
  vehicles: Array<Vehicle>;
  treasuryContract?: Maybe<TreasuryContract>;
  treasuryContracts: Array<TreasuryContract>;
  collateralLock?: Maybe<CollateralLock>;
  collateralLocks: Array<CollateralLock>;
  marketplaceContract?: Maybe<MarketplaceContract>;
  marketplaceContracts: Array<MarketplaceContract>;
  listing?: Maybe<Listing>;
  listings: Array<Listing>;
  /** Access to subgraph metadata */
  _meta?: Maybe<_Meta_>;
};


export type SubscriptionmockUSDCContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionmockUSDCContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<MockUSDCContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<MockUSDCContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontransferArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontransfersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Transfer_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Transfer_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionroboshareTokensContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionroboshareTokensContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RoboshareTokensContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RoboshareTokensContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionroboshareTokenArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionroboshareTokensArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RoboshareToken_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RoboshareToken_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontransferSingleEventArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontransferSingleEventsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<TransferSingleEvent_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<TransferSingleEvent_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionpartnerManagerContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionpartnerManagerContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<PartnerManagerContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<PartnerManagerContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionpartnerArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionpartnersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Partner_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Partner_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionregistryRouterContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionregistryRouterContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RegistryRouterContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RegistryRouterContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionregisteredAssetRouterArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionregisteredAssetRoutersArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<RegisteredAssetRouter_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<RegisteredAssetRouter_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionvehicleRegistryContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionvehicleRegistryContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<VehicleRegistryContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<VehicleRegistryContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionvehicleArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionvehiclesArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Vehicle_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Vehicle_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontreasuryContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptiontreasuryContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<TreasuryContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<TreasuryContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptioncollateralLockArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptioncollateralLocksArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<CollateralLock_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<CollateralLock_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionmarketplaceContractArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionmarketplaceContractsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<MarketplaceContract_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<MarketplaceContract_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionlistingArgs = {
  id: Scalars['ID']['input'];
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type SubscriptionlistingsArgs = {
  skip?: InputMaybe<Scalars['Int']['input']>;
  first?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Listing_orderBy>;
  orderDirection?: InputMaybe<OrderDirection>;
  where?: InputMaybe<Listing_filter>;
  block?: InputMaybe<Block_height>;
  subgraphError?: _SubgraphErrorPolicy_;
};


export type Subscription_metaArgs = {
  block?: InputMaybe<Block_height>;
};

export type Transfer = {
  id: Scalars['ID']['output'];
  from: Scalars['Bytes']['output'];
  to: Scalars['Bytes']['output'];
  value: Scalars['BigInt']['output'];
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type TransferSingleEvent = {
  id: Scalars['ID']['output'];
  operator: Scalars['Bytes']['output'];
  from: Scalars['Bytes']['output'];
  to: Scalars['Bytes']['output'];
  tokenId: Scalars['BigInt']['output'];
  value: Scalars['BigInt']['output'];
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type TransferSingleEvent_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  operator?: InputMaybe<Scalars['Bytes']['input']>;
  operator_not?: InputMaybe<Scalars['Bytes']['input']>;
  operator_gt?: InputMaybe<Scalars['Bytes']['input']>;
  operator_lt?: InputMaybe<Scalars['Bytes']['input']>;
  operator_gte?: InputMaybe<Scalars['Bytes']['input']>;
  operator_lte?: InputMaybe<Scalars['Bytes']['input']>;
  operator_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  operator_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  operator_contains?: InputMaybe<Scalars['Bytes']['input']>;
  operator_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  from?: InputMaybe<Scalars['Bytes']['input']>;
  from_not?: InputMaybe<Scalars['Bytes']['input']>;
  from_gt?: InputMaybe<Scalars['Bytes']['input']>;
  from_lt?: InputMaybe<Scalars['Bytes']['input']>;
  from_gte?: InputMaybe<Scalars['Bytes']['input']>;
  from_lte?: InputMaybe<Scalars['Bytes']['input']>;
  from_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  from_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  from_contains?: InputMaybe<Scalars['Bytes']['input']>;
  from_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  to?: InputMaybe<Scalars['Bytes']['input']>;
  to_not?: InputMaybe<Scalars['Bytes']['input']>;
  to_gt?: InputMaybe<Scalars['Bytes']['input']>;
  to_lt?: InputMaybe<Scalars['Bytes']['input']>;
  to_gte?: InputMaybe<Scalars['Bytes']['input']>;
  to_lte?: InputMaybe<Scalars['Bytes']['input']>;
  to_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  to_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  to_contains?: InputMaybe<Scalars['Bytes']['input']>;
  to_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  tokenId?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_not?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_gt?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_lt?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_gte?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_lte?: InputMaybe<Scalars['BigInt']['input']>;
  tokenId_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  tokenId_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  value?: InputMaybe<Scalars['BigInt']['input']>;
  value_not?: InputMaybe<Scalars['BigInt']['input']>;
  value_gt?: InputMaybe<Scalars['BigInt']['input']>;
  value_lt?: InputMaybe<Scalars['BigInt']['input']>;
  value_gte?: InputMaybe<Scalars['BigInt']['input']>;
  value_lte?: InputMaybe<Scalars['BigInt']['input']>;
  value_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  value_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<TransferSingleEvent_filter>>>;
  or?: InputMaybe<Array<InputMaybe<TransferSingleEvent_filter>>>;
};

export type TransferSingleEvent_orderBy =
  | 'id'
  | 'operator'
  | 'from'
  | 'to'
  | 'tokenId'
  | 'value'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type Transfer_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  from?: InputMaybe<Scalars['Bytes']['input']>;
  from_not?: InputMaybe<Scalars['Bytes']['input']>;
  from_gt?: InputMaybe<Scalars['Bytes']['input']>;
  from_lt?: InputMaybe<Scalars['Bytes']['input']>;
  from_gte?: InputMaybe<Scalars['Bytes']['input']>;
  from_lte?: InputMaybe<Scalars['Bytes']['input']>;
  from_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  from_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  from_contains?: InputMaybe<Scalars['Bytes']['input']>;
  from_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  to?: InputMaybe<Scalars['Bytes']['input']>;
  to_not?: InputMaybe<Scalars['Bytes']['input']>;
  to_gt?: InputMaybe<Scalars['Bytes']['input']>;
  to_lt?: InputMaybe<Scalars['Bytes']['input']>;
  to_gte?: InputMaybe<Scalars['Bytes']['input']>;
  to_lte?: InputMaybe<Scalars['Bytes']['input']>;
  to_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  to_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  to_contains?: InputMaybe<Scalars['Bytes']['input']>;
  to_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  value?: InputMaybe<Scalars['BigInt']['input']>;
  value_not?: InputMaybe<Scalars['BigInt']['input']>;
  value_gt?: InputMaybe<Scalars['BigInt']['input']>;
  value_lt?: InputMaybe<Scalars['BigInt']['input']>;
  value_gte?: InputMaybe<Scalars['BigInt']['input']>;
  value_lte?: InputMaybe<Scalars['BigInt']['input']>;
  value_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  value_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<Transfer_filter>>>;
  or?: InputMaybe<Array<InputMaybe<Transfer_filter>>>;
};

export type Transfer_orderBy =
  | 'id'
  | 'from'
  | 'to'
  | 'value'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type TreasuryContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type TreasuryContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<TreasuryContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<TreasuryContract_filter>>>;
};

export type TreasuryContract_orderBy =
  | 'id'
  | 'address';

export type Vehicle = {
  id: Scalars['ID']['output'];
  partner: Scalars['Bytes']['output'];
  vin: Scalars['String']['output'];
  make?: Maybe<Scalars['String']['output']>;
  model?: Maybe<Scalars['String']['output']>;
  year?: Maybe<Scalars['BigInt']['output']>;
  blockNumber: Scalars['BigInt']['output'];
  blockTimestamp: Scalars['BigInt']['output'];
  transactionHash: Scalars['Bytes']['output'];
};

export type VehicleRegistryContract = {
  id: Scalars['ID']['output'];
  address: Scalars['Bytes']['output'];
};

export type VehicleRegistryContract_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  address?: InputMaybe<Scalars['Bytes']['input']>;
  address_not?: InputMaybe<Scalars['Bytes']['input']>;
  address_gt?: InputMaybe<Scalars['Bytes']['input']>;
  address_lt?: InputMaybe<Scalars['Bytes']['input']>;
  address_gte?: InputMaybe<Scalars['Bytes']['input']>;
  address_lte?: InputMaybe<Scalars['Bytes']['input']>;
  address_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  address_contains?: InputMaybe<Scalars['Bytes']['input']>;
  address_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<VehicleRegistryContract_filter>>>;
  or?: InputMaybe<Array<InputMaybe<VehicleRegistryContract_filter>>>;
};

export type VehicleRegistryContract_orderBy =
  | 'id'
  | 'address';

export type Vehicle_filter = {
  id?: InputMaybe<Scalars['ID']['input']>;
  id_not?: InputMaybe<Scalars['ID']['input']>;
  id_gt?: InputMaybe<Scalars['ID']['input']>;
  id_lt?: InputMaybe<Scalars['ID']['input']>;
  id_gte?: InputMaybe<Scalars['ID']['input']>;
  id_lte?: InputMaybe<Scalars['ID']['input']>;
  id_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  id_not_in?: InputMaybe<Array<Scalars['ID']['input']>>;
  partner?: InputMaybe<Scalars['Bytes']['input']>;
  partner_not?: InputMaybe<Scalars['Bytes']['input']>;
  partner_gt?: InputMaybe<Scalars['Bytes']['input']>;
  partner_lt?: InputMaybe<Scalars['Bytes']['input']>;
  partner_gte?: InputMaybe<Scalars['Bytes']['input']>;
  partner_lte?: InputMaybe<Scalars['Bytes']['input']>;
  partner_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  partner_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  partner_contains?: InputMaybe<Scalars['Bytes']['input']>;
  partner_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  vin?: InputMaybe<Scalars['String']['input']>;
  vin_not?: InputMaybe<Scalars['String']['input']>;
  vin_gt?: InputMaybe<Scalars['String']['input']>;
  vin_lt?: InputMaybe<Scalars['String']['input']>;
  vin_gte?: InputMaybe<Scalars['String']['input']>;
  vin_lte?: InputMaybe<Scalars['String']['input']>;
  vin_in?: InputMaybe<Array<Scalars['String']['input']>>;
  vin_not_in?: InputMaybe<Array<Scalars['String']['input']>>;
  vin_contains?: InputMaybe<Scalars['String']['input']>;
  vin_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  vin_not_contains?: InputMaybe<Scalars['String']['input']>;
  vin_not_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  vin_starts_with?: InputMaybe<Scalars['String']['input']>;
  vin_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  vin_not_starts_with?: InputMaybe<Scalars['String']['input']>;
  vin_not_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  vin_ends_with?: InputMaybe<Scalars['String']['input']>;
  vin_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  vin_not_ends_with?: InputMaybe<Scalars['String']['input']>;
  vin_not_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  make?: InputMaybe<Scalars['String']['input']>;
  make_not?: InputMaybe<Scalars['String']['input']>;
  make_gt?: InputMaybe<Scalars['String']['input']>;
  make_lt?: InputMaybe<Scalars['String']['input']>;
  make_gte?: InputMaybe<Scalars['String']['input']>;
  make_lte?: InputMaybe<Scalars['String']['input']>;
  make_in?: InputMaybe<Array<Scalars['String']['input']>>;
  make_not_in?: InputMaybe<Array<Scalars['String']['input']>>;
  make_contains?: InputMaybe<Scalars['String']['input']>;
  make_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  make_not_contains?: InputMaybe<Scalars['String']['input']>;
  make_not_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  make_starts_with?: InputMaybe<Scalars['String']['input']>;
  make_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  make_not_starts_with?: InputMaybe<Scalars['String']['input']>;
  make_not_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  make_ends_with?: InputMaybe<Scalars['String']['input']>;
  make_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  make_not_ends_with?: InputMaybe<Scalars['String']['input']>;
  make_not_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  model?: InputMaybe<Scalars['String']['input']>;
  model_not?: InputMaybe<Scalars['String']['input']>;
  model_gt?: InputMaybe<Scalars['String']['input']>;
  model_lt?: InputMaybe<Scalars['String']['input']>;
  model_gte?: InputMaybe<Scalars['String']['input']>;
  model_lte?: InputMaybe<Scalars['String']['input']>;
  model_in?: InputMaybe<Array<Scalars['String']['input']>>;
  model_not_in?: InputMaybe<Array<Scalars['String']['input']>>;
  model_contains?: InputMaybe<Scalars['String']['input']>;
  model_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  model_not_contains?: InputMaybe<Scalars['String']['input']>;
  model_not_contains_nocase?: InputMaybe<Scalars['String']['input']>;
  model_starts_with?: InputMaybe<Scalars['String']['input']>;
  model_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  model_not_starts_with?: InputMaybe<Scalars['String']['input']>;
  model_not_starts_with_nocase?: InputMaybe<Scalars['String']['input']>;
  model_ends_with?: InputMaybe<Scalars['String']['input']>;
  model_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  model_not_ends_with?: InputMaybe<Scalars['String']['input']>;
  model_not_ends_with_nocase?: InputMaybe<Scalars['String']['input']>;
  year?: InputMaybe<Scalars['BigInt']['input']>;
  year_not?: InputMaybe<Scalars['BigInt']['input']>;
  year_gt?: InputMaybe<Scalars['BigInt']['input']>;
  year_lt?: InputMaybe<Scalars['BigInt']['input']>;
  year_gte?: InputMaybe<Scalars['BigInt']['input']>;
  year_lte?: InputMaybe<Scalars['BigInt']['input']>;
  year_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  year_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockNumber_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockNumber_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_not?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lt?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_gte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_lte?: InputMaybe<Scalars['BigInt']['input']>;
  blockTimestamp_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  blockTimestamp_not_in?: InputMaybe<Array<Scalars['BigInt']['input']>>;
  transactionHash?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lt?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_gte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_lte?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_not_in?: InputMaybe<Array<Scalars['Bytes']['input']>>;
  transactionHash_contains?: InputMaybe<Scalars['Bytes']['input']>;
  transactionHash_not_contains?: InputMaybe<Scalars['Bytes']['input']>;
  /** Filter for the block changed event. */
  _change_block?: InputMaybe<BlockChangedFilter>;
  and?: InputMaybe<Array<InputMaybe<Vehicle_filter>>>;
  or?: InputMaybe<Array<InputMaybe<Vehicle_filter>>>;
};

export type Vehicle_orderBy =
  | 'id'
  | 'partner'
  | 'vin'
  | 'make'
  | 'model'
  | 'year'
  | 'blockNumber'
  | 'blockTimestamp'
  | 'transactionHash';

export type _Block_ = {
  /** The hash of the block */
  hash?: Maybe<Scalars['Bytes']['output']>;
  /** The block number */
  number: Scalars['Int']['output'];
  /** Integer representation of the timestamp stored in blocks for the chain */
  timestamp?: Maybe<Scalars['Int']['output']>;
  /** The hash of the parent block */
  parentHash?: Maybe<Scalars['Bytes']['output']>;
};

/** The type for the top-level _meta field */
export type _Meta_ = {
  /**
   * Information about a specific subgraph block. The hash of the block
   * will be null if the _meta field has a block constraint that asks for
   * a block number. It will be filled if the _meta field has no block constraint
   * and therefore asks for the latest  block
   *
   */
  block: _Block_;
  /** The deployment ID */
  deployment: Scalars['String']['output'];
  /** If `true`, the subgraph encountered indexing errors at some past block */
  hasIndexingErrors: Scalars['Boolean']['output'];
};

export type _SubgraphErrorPolicy_ =
  /** Data will be returned even if the subgraph has indexing errors */
  | 'allow'
  /** If the subgraph has indexing errors, data will be omitted. The default. */
  | 'deny';

export type WithIndex<TObject> = TObject & Record<string, any>;
export type ResolversObject<TObject> = WithIndex<TObject>;

export type ResolverTypeWrapper<T> = Promise<T> | T;


export type ResolverWithResolve<TResult, TParent, TContext, TArgs> = {
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>;
};

export type LegacyStitchingResolver<TResult, TParent, TContext, TArgs> = {
  fragment: string;
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>;
};

export type NewStitchingResolver<TResult, TParent, TContext, TArgs> = {
  selectionSet: string | ((fieldNode: FieldNode) => SelectionSetNode);
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>;
};
export type StitchingResolver<TResult, TParent, TContext, TArgs> = LegacyStitchingResolver<TResult, TParent, TContext, TArgs> | NewStitchingResolver<TResult, TParent, TContext, TArgs>;
export type Resolver<TResult, TParent = {}, TContext = {}, TArgs = {}> =
  | ResolverFn<TResult, TParent, TContext, TArgs>
  | ResolverWithResolve<TResult, TParent, TContext, TArgs>
  | StitchingResolver<TResult, TParent, TContext, TArgs>;

export type ResolverFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => Promise<TResult> | TResult;

export type SubscriptionSubscribeFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => AsyncIterable<TResult> | Promise<AsyncIterable<TResult>>;

export type SubscriptionResolveFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;

export interface SubscriptionSubscriberObject<TResult, TKey extends string, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<{ [key in TKey]: TResult }, TParent, TContext, TArgs>;
  resolve?: SubscriptionResolveFn<TResult, { [key in TKey]: TResult }, TContext, TArgs>;
}

export interface SubscriptionResolverObject<TResult, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<any, TParent, TContext, TArgs>;
  resolve: SubscriptionResolveFn<TResult, any, TContext, TArgs>;
}

export type SubscriptionObject<TResult, TKey extends string, TParent, TContext, TArgs> =
  | SubscriptionSubscriberObject<TResult, TKey, TParent, TContext, TArgs>
  | SubscriptionResolverObject<TResult, TParent, TContext, TArgs>;

export type SubscriptionResolver<TResult, TKey extends string, TParent = {}, TContext = {}, TArgs = {}> =
  | ((...args: any[]) => SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>)
  | SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>;

export type TypeResolveFn<TTypes, TParent = {}, TContext = {}> = (
  parent: TParent,
  context: TContext,
  info: GraphQLResolveInfo
) => Maybe<TTypes> | Promise<Maybe<TTypes>>;

export type IsTypeOfResolverFn<T = {}, TContext = {}> = (obj: T, context: TContext, info: GraphQLResolveInfo) => boolean | Promise<boolean>;

export type NextResolverFn<T> = () => Promise<T>;

export type DirectiveResolverFn<TResult = {}, TParent = {}, TContext = {}, TArgs = {}> = (
  next: NextResolverFn<TResult>,
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;



/** Mapping between all available schema types and the resolvers types */
export type ResolversTypes = ResolversObject<{
  Aggregation_interval: Aggregation_interval;
  BigDecimal: ResolverTypeWrapper<Scalars['BigDecimal']['output']>;
  BigInt: ResolverTypeWrapper<Scalars['BigInt']['output']>;
  BlockChangedFilter: BlockChangedFilter;
  Block_height: Block_height;
  Boolean: ResolverTypeWrapper<Scalars['Boolean']['output']>;
  Bytes: ResolverTypeWrapper<Scalars['Bytes']['output']>;
  CollateralLock: ResolverTypeWrapper<CollateralLock>;
  CollateralLock_filter: CollateralLock_filter;
  CollateralLock_orderBy: CollateralLock_orderBy;
  Float: ResolverTypeWrapper<Scalars['Float']['output']>;
  ID: ResolverTypeWrapper<Scalars['ID']['output']>;
  Int: ResolverTypeWrapper<Scalars['Int']['output']>;
  Int8: ResolverTypeWrapper<Scalars['Int8']['output']>;
  Listing: ResolverTypeWrapper<Listing>;
  Listing_filter: Listing_filter;
  Listing_orderBy: Listing_orderBy;
  MarketplaceContract: ResolverTypeWrapper<MarketplaceContract>;
  MarketplaceContract_filter: MarketplaceContract_filter;
  MarketplaceContract_orderBy: MarketplaceContract_orderBy;
  MockUSDCContract: ResolverTypeWrapper<MockUSDCContract>;
  MockUSDCContract_filter: MockUSDCContract_filter;
  MockUSDCContract_orderBy: MockUSDCContract_orderBy;
  OrderDirection: OrderDirection;
  Partner: ResolverTypeWrapper<Partner>;
  PartnerManagerContract: ResolverTypeWrapper<PartnerManagerContract>;
  PartnerManagerContract_filter: PartnerManagerContract_filter;
  PartnerManagerContract_orderBy: PartnerManagerContract_orderBy;
  Partner_filter: Partner_filter;
  Partner_orderBy: Partner_orderBy;
  Query: ResolverTypeWrapper<{}>;
  RegisteredAssetRouter: ResolverTypeWrapper<RegisteredAssetRouter>;
  RegisteredAssetRouter_filter: RegisteredAssetRouter_filter;
  RegisteredAssetRouter_orderBy: RegisteredAssetRouter_orderBy;
  RegistryRouterContract: ResolverTypeWrapper<RegistryRouterContract>;
  RegistryRouterContract_filter: RegistryRouterContract_filter;
  RegistryRouterContract_orderBy: RegistryRouterContract_orderBy;
  RoboshareToken: ResolverTypeWrapper<RoboshareToken>;
  RoboshareToken_filter: RoboshareToken_filter;
  RoboshareToken_orderBy: RoboshareToken_orderBy;
  RoboshareTokensContract: ResolverTypeWrapper<RoboshareTokensContract>;
  RoboshareTokensContract_filter: RoboshareTokensContract_filter;
  RoboshareTokensContract_orderBy: RoboshareTokensContract_orderBy;
  String: ResolverTypeWrapper<Scalars['String']['output']>;
  Subscription: ResolverTypeWrapper<{}>;
  Timestamp: ResolverTypeWrapper<Scalars['Timestamp']['output']>;
  Transfer: ResolverTypeWrapper<Transfer>;
  TransferSingleEvent: ResolverTypeWrapper<TransferSingleEvent>;
  TransferSingleEvent_filter: TransferSingleEvent_filter;
  TransferSingleEvent_orderBy: TransferSingleEvent_orderBy;
  Transfer_filter: Transfer_filter;
  Transfer_orderBy: Transfer_orderBy;
  TreasuryContract: ResolverTypeWrapper<TreasuryContract>;
  TreasuryContract_filter: TreasuryContract_filter;
  TreasuryContract_orderBy: TreasuryContract_orderBy;
  Vehicle: ResolverTypeWrapper<Vehicle>;
  VehicleRegistryContract: ResolverTypeWrapper<VehicleRegistryContract>;
  VehicleRegistryContract_filter: VehicleRegistryContract_filter;
  VehicleRegistryContract_orderBy: VehicleRegistryContract_orderBy;
  Vehicle_filter: Vehicle_filter;
  Vehicle_orderBy: Vehicle_orderBy;
  _Block_: ResolverTypeWrapper<_Block_>;
  _Meta_: ResolverTypeWrapper<_Meta_>;
  _SubgraphErrorPolicy_: _SubgraphErrorPolicy_;
}>;

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = ResolversObject<{
  BigDecimal: Scalars['BigDecimal']['output'];
  BigInt: Scalars['BigInt']['output'];
  BlockChangedFilter: BlockChangedFilter;
  Block_height: Block_height;
  Boolean: Scalars['Boolean']['output'];
  Bytes: Scalars['Bytes']['output'];
  CollateralLock: CollateralLock;
  CollateralLock_filter: CollateralLock_filter;
  Float: Scalars['Float']['output'];
  ID: Scalars['ID']['output'];
  Int: Scalars['Int']['output'];
  Int8: Scalars['Int8']['output'];
  Listing: Listing;
  Listing_filter: Listing_filter;
  MarketplaceContract: MarketplaceContract;
  MarketplaceContract_filter: MarketplaceContract_filter;
  MockUSDCContract: MockUSDCContract;
  MockUSDCContract_filter: MockUSDCContract_filter;
  Partner: Partner;
  PartnerManagerContract: PartnerManagerContract;
  PartnerManagerContract_filter: PartnerManagerContract_filter;
  Partner_filter: Partner_filter;
  Query: {};
  RegisteredAssetRouter: RegisteredAssetRouter;
  RegisteredAssetRouter_filter: RegisteredAssetRouter_filter;
  RegistryRouterContract: RegistryRouterContract;
  RegistryRouterContract_filter: RegistryRouterContract_filter;
  RoboshareToken: RoboshareToken;
  RoboshareToken_filter: RoboshareToken_filter;
  RoboshareTokensContract: RoboshareTokensContract;
  RoboshareTokensContract_filter: RoboshareTokensContract_filter;
  String: Scalars['String']['output'];
  Subscription: {};
  Timestamp: Scalars['Timestamp']['output'];
  Transfer: Transfer;
  TransferSingleEvent: TransferSingleEvent;
  TransferSingleEvent_filter: TransferSingleEvent_filter;
  Transfer_filter: Transfer_filter;
  TreasuryContract: TreasuryContract;
  TreasuryContract_filter: TreasuryContract_filter;
  Vehicle: Vehicle;
  VehicleRegistryContract: VehicleRegistryContract;
  VehicleRegistryContract_filter: VehicleRegistryContract_filter;
  Vehicle_filter: Vehicle_filter;
  _Block_: _Block_;
  _Meta_: _Meta_;
}>;

export type entityDirectiveArgs = { };

export type entityDirectiveResolver<Result, Parent, ContextType = MeshContext, Args = entityDirectiveArgs> = DirectiveResolverFn<Result, Parent, ContextType, Args>;

export type subgraphIdDirectiveArgs = {
  id: Scalars['String']['input'];
};

export type subgraphIdDirectiveResolver<Result, Parent, ContextType = MeshContext, Args = subgraphIdDirectiveArgs> = DirectiveResolverFn<Result, Parent, ContextType, Args>;

export type derivedFromDirectiveArgs = {
  field: Scalars['String']['input'];
};

export type derivedFromDirectiveResolver<Result, Parent, ContextType = MeshContext, Args = derivedFromDirectiveArgs> = DirectiveResolverFn<Result, Parent, ContextType, Args>;

export interface BigDecimalScalarConfig extends GraphQLScalarTypeConfig<ResolversTypes['BigDecimal'], any> {
  name: 'BigDecimal';
}

export interface BigIntScalarConfig extends GraphQLScalarTypeConfig<ResolversTypes['BigInt'], any> {
  name: 'BigInt';
}

export interface BytesScalarConfig extends GraphQLScalarTypeConfig<ResolversTypes['Bytes'], any> {
  name: 'Bytes';
}

export type CollateralLockResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['CollateralLock'] = ResolversParentTypes['CollateralLock']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  assetId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  partner?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  amount?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export interface Int8ScalarConfig extends GraphQLScalarTypeConfig<ResolversTypes['Int8'], any> {
  name: 'Int8';
}

export type ListingResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Listing'] = ResolversParentTypes['Listing']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  tokenId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  assetId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  seller?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  amount?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  pricePerToken?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  expiresAt?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  buyerPaysFee?: Resolver<ResolversTypes['Boolean'], ParentType, ContextType>;
  createdAt?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type MarketplaceContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['MarketplaceContract'] = ResolversParentTypes['MarketplaceContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type MockUSDCContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['MockUSDCContract'] = ResolversParentTypes['MockUSDCContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type PartnerResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Partner'] = ResolversParentTypes['Partner']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  name?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  authorizedAt?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type PartnerManagerContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['PartnerManagerContract'] = ResolversParentTypes['PartnerManagerContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type QueryResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Query'] = ResolversParentTypes['Query']> = ResolversObject<{
  mockUSDCContract?: Resolver<Maybe<ResolversTypes['MockUSDCContract']>, ParentType, ContextType, RequireFields<QuerymockUSDCContractArgs, 'id' | 'subgraphError'>>;
  mockUSDCContracts?: Resolver<Array<ResolversTypes['MockUSDCContract']>, ParentType, ContextType, RequireFields<QuerymockUSDCContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  transfer?: Resolver<Maybe<ResolversTypes['Transfer']>, ParentType, ContextType, RequireFields<QuerytransferArgs, 'id' | 'subgraphError'>>;
  transfers?: Resolver<Array<ResolversTypes['Transfer']>, ParentType, ContextType, RequireFields<QuerytransfersArgs, 'skip' | 'first' | 'subgraphError'>>;
  roboshareTokensContract?: Resolver<Maybe<ResolversTypes['RoboshareTokensContract']>, ParentType, ContextType, RequireFields<QueryroboshareTokensContractArgs, 'id' | 'subgraphError'>>;
  roboshareTokensContracts?: Resolver<Array<ResolversTypes['RoboshareTokensContract']>, ParentType, ContextType, RequireFields<QueryroboshareTokensContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  roboshareToken?: Resolver<Maybe<ResolversTypes['RoboshareToken']>, ParentType, ContextType, RequireFields<QueryroboshareTokenArgs, 'id' | 'subgraphError'>>;
  roboshareTokens?: Resolver<Array<ResolversTypes['RoboshareToken']>, ParentType, ContextType, RequireFields<QueryroboshareTokensArgs, 'skip' | 'first' | 'subgraphError'>>;
  transferSingleEvent?: Resolver<Maybe<ResolversTypes['TransferSingleEvent']>, ParentType, ContextType, RequireFields<QuerytransferSingleEventArgs, 'id' | 'subgraphError'>>;
  transferSingleEvents?: Resolver<Array<ResolversTypes['TransferSingleEvent']>, ParentType, ContextType, RequireFields<QuerytransferSingleEventsArgs, 'skip' | 'first' | 'subgraphError'>>;
  partnerManagerContract?: Resolver<Maybe<ResolversTypes['PartnerManagerContract']>, ParentType, ContextType, RequireFields<QuerypartnerManagerContractArgs, 'id' | 'subgraphError'>>;
  partnerManagerContracts?: Resolver<Array<ResolversTypes['PartnerManagerContract']>, ParentType, ContextType, RequireFields<QuerypartnerManagerContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  partner?: Resolver<Maybe<ResolversTypes['Partner']>, ParentType, ContextType, RequireFields<QuerypartnerArgs, 'id' | 'subgraphError'>>;
  partners?: Resolver<Array<ResolversTypes['Partner']>, ParentType, ContextType, RequireFields<QuerypartnersArgs, 'skip' | 'first' | 'subgraphError'>>;
  registryRouterContract?: Resolver<Maybe<ResolversTypes['RegistryRouterContract']>, ParentType, ContextType, RequireFields<QueryregistryRouterContractArgs, 'id' | 'subgraphError'>>;
  registryRouterContracts?: Resolver<Array<ResolversTypes['RegistryRouterContract']>, ParentType, ContextType, RequireFields<QueryregistryRouterContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  registeredAssetRouter?: Resolver<Maybe<ResolversTypes['RegisteredAssetRouter']>, ParentType, ContextType, RequireFields<QueryregisteredAssetRouterArgs, 'id' | 'subgraphError'>>;
  registeredAssetRouters?: Resolver<Array<ResolversTypes['RegisteredAssetRouter']>, ParentType, ContextType, RequireFields<QueryregisteredAssetRoutersArgs, 'skip' | 'first' | 'subgraphError'>>;
  vehicleRegistryContract?: Resolver<Maybe<ResolversTypes['VehicleRegistryContract']>, ParentType, ContextType, RequireFields<QueryvehicleRegistryContractArgs, 'id' | 'subgraphError'>>;
  vehicleRegistryContracts?: Resolver<Array<ResolversTypes['VehicleRegistryContract']>, ParentType, ContextType, RequireFields<QueryvehicleRegistryContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  vehicle?: Resolver<Maybe<ResolversTypes['Vehicle']>, ParentType, ContextType, RequireFields<QueryvehicleArgs, 'id' | 'subgraphError'>>;
  vehicles?: Resolver<Array<ResolversTypes['Vehicle']>, ParentType, ContextType, RequireFields<QueryvehiclesArgs, 'skip' | 'first' | 'subgraphError'>>;
  treasuryContract?: Resolver<Maybe<ResolversTypes['TreasuryContract']>, ParentType, ContextType, RequireFields<QuerytreasuryContractArgs, 'id' | 'subgraphError'>>;
  treasuryContracts?: Resolver<Array<ResolversTypes['TreasuryContract']>, ParentType, ContextType, RequireFields<QuerytreasuryContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  collateralLock?: Resolver<Maybe<ResolversTypes['CollateralLock']>, ParentType, ContextType, RequireFields<QuerycollateralLockArgs, 'id' | 'subgraphError'>>;
  collateralLocks?: Resolver<Array<ResolversTypes['CollateralLock']>, ParentType, ContextType, RequireFields<QuerycollateralLocksArgs, 'skip' | 'first' | 'subgraphError'>>;
  marketplaceContract?: Resolver<Maybe<ResolversTypes['MarketplaceContract']>, ParentType, ContextType, RequireFields<QuerymarketplaceContractArgs, 'id' | 'subgraphError'>>;
  marketplaceContracts?: Resolver<Array<ResolversTypes['MarketplaceContract']>, ParentType, ContextType, RequireFields<QuerymarketplaceContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  listing?: Resolver<Maybe<ResolversTypes['Listing']>, ParentType, ContextType, RequireFields<QuerylistingArgs, 'id' | 'subgraphError'>>;
  listings?: Resolver<Array<ResolversTypes['Listing']>, ParentType, ContextType, RequireFields<QuerylistingsArgs, 'skip' | 'first' | 'subgraphError'>>;
  _meta?: Resolver<Maybe<ResolversTypes['_Meta_']>, ParentType, ContextType, Partial<Query_metaArgs>>;
}>;

export type RegisteredAssetRouterResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['RegisteredAssetRouter'] = ResolversParentTypes['RegisteredAssetRouter']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  assetId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  owner?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  status?: Resolver<ResolversTypes['Int'], ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type RegistryRouterContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['RegistryRouterContract'] = ResolversParentTypes['RegistryRouterContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type RoboshareTokenResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['RoboshareToken'] = ResolversParentTypes['RoboshareToken']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  revenueTokenId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  price?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  supply?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  maturityDate?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  setAtBlock?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type RoboshareTokensContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['RoboshareTokensContract'] = ResolversParentTypes['RoboshareTokensContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type SubscriptionResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Subscription'] = ResolversParentTypes['Subscription']> = ResolversObject<{
  mockUSDCContract?: SubscriptionResolver<Maybe<ResolversTypes['MockUSDCContract']>, "mockUSDCContract", ParentType, ContextType, RequireFields<SubscriptionmockUSDCContractArgs, 'id' | 'subgraphError'>>;
  mockUSDCContracts?: SubscriptionResolver<Array<ResolversTypes['MockUSDCContract']>, "mockUSDCContracts", ParentType, ContextType, RequireFields<SubscriptionmockUSDCContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  transfer?: SubscriptionResolver<Maybe<ResolversTypes['Transfer']>, "transfer", ParentType, ContextType, RequireFields<SubscriptiontransferArgs, 'id' | 'subgraphError'>>;
  transfers?: SubscriptionResolver<Array<ResolversTypes['Transfer']>, "transfers", ParentType, ContextType, RequireFields<SubscriptiontransfersArgs, 'skip' | 'first' | 'subgraphError'>>;
  roboshareTokensContract?: SubscriptionResolver<Maybe<ResolversTypes['RoboshareTokensContract']>, "roboshareTokensContract", ParentType, ContextType, RequireFields<SubscriptionroboshareTokensContractArgs, 'id' | 'subgraphError'>>;
  roboshareTokensContracts?: SubscriptionResolver<Array<ResolversTypes['RoboshareTokensContract']>, "roboshareTokensContracts", ParentType, ContextType, RequireFields<SubscriptionroboshareTokensContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  roboshareToken?: SubscriptionResolver<Maybe<ResolversTypes['RoboshareToken']>, "roboshareToken", ParentType, ContextType, RequireFields<SubscriptionroboshareTokenArgs, 'id' | 'subgraphError'>>;
  roboshareTokens?: SubscriptionResolver<Array<ResolversTypes['RoboshareToken']>, "roboshareTokens", ParentType, ContextType, RequireFields<SubscriptionroboshareTokensArgs, 'skip' | 'first' | 'subgraphError'>>;
  transferSingleEvent?: SubscriptionResolver<Maybe<ResolversTypes['TransferSingleEvent']>, "transferSingleEvent", ParentType, ContextType, RequireFields<SubscriptiontransferSingleEventArgs, 'id' | 'subgraphError'>>;
  transferSingleEvents?: SubscriptionResolver<Array<ResolversTypes['TransferSingleEvent']>, "transferSingleEvents", ParentType, ContextType, RequireFields<SubscriptiontransferSingleEventsArgs, 'skip' | 'first' | 'subgraphError'>>;
  partnerManagerContract?: SubscriptionResolver<Maybe<ResolversTypes['PartnerManagerContract']>, "partnerManagerContract", ParentType, ContextType, RequireFields<SubscriptionpartnerManagerContractArgs, 'id' | 'subgraphError'>>;
  partnerManagerContracts?: SubscriptionResolver<Array<ResolversTypes['PartnerManagerContract']>, "partnerManagerContracts", ParentType, ContextType, RequireFields<SubscriptionpartnerManagerContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  partner?: SubscriptionResolver<Maybe<ResolversTypes['Partner']>, "partner", ParentType, ContextType, RequireFields<SubscriptionpartnerArgs, 'id' | 'subgraphError'>>;
  partners?: SubscriptionResolver<Array<ResolversTypes['Partner']>, "partners", ParentType, ContextType, RequireFields<SubscriptionpartnersArgs, 'skip' | 'first' | 'subgraphError'>>;
  registryRouterContract?: SubscriptionResolver<Maybe<ResolversTypes['RegistryRouterContract']>, "registryRouterContract", ParentType, ContextType, RequireFields<SubscriptionregistryRouterContractArgs, 'id' | 'subgraphError'>>;
  registryRouterContracts?: SubscriptionResolver<Array<ResolversTypes['RegistryRouterContract']>, "registryRouterContracts", ParentType, ContextType, RequireFields<SubscriptionregistryRouterContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  registeredAssetRouter?: SubscriptionResolver<Maybe<ResolversTypes['RegisteredAssetRouter']>, "registeredAssetRouter", ParentType, ContextType, RequireFields<SubscriptionregisteredAssetRouterArgs, 'id' | 'subgraphError'>>;
  registeredAssetRouters?: SubscriptionResolver<Array<ResolversTypes['RegisteredAssetRouter']>, "registeredAssetRouters", ParentType, ContextType, RequireFields<SubscriptionregisteredAssetRoutersArgs, 'skip' | 'first' | 'subgraphError'>>;
  vehicleRegistryContract?: SubscriptionResolver<Maybe<ResolversTypes['VehicleRegistryContract']>, "vehicleRegistryContract", ParentType, ContextType, RequireFields<SubscriptionvehicleRegistryContractArgs, 'id' | 'subgraphError'>>;
  vehicleRegistryContracts?: SubscriptionResolver<Array<ResolversTypes['VehicleRegistryContract']>, "vehicleRegistryContracts", ParentType, ContextType, RequireFields<SubscriptionvehicleRegistryContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  vehicle?: SubscriptionResolver<Maybe<ResolversTypes['Vehicle']>, "vehicle", ParentType, ContextType, RequireFields<SubscriptionvehicleArgs, 'id' | 'subgraphError'>>;
  vehicles?: SubscriptionResolver<Array<ResolversTypes['Vehicle']>, "vehicles", ParentType, ContextType, RequireFields<SubscriptionvehiclesArgs, 'skip' | 'first' | 'subgraphError'>>;
  treasuryContract?: SubscriptionResolver<Maybe<ResolversTypes['TreasuryContract']>, "treasuryContract", ParentType, ContextType, RequireFields<SubscriptiontreasuryContractArgs, 'id' | 'subgraphError'>>;
  treasuryContracts?: SubscriptionResolver<Array<ResolversTypes['TreasuryContract']>, "treasuryContracts", ParentType, ContextType, RequireFields<SubscriptiontreasuryContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  collateralLock?: SubscriptionResolver<Maybe<ResolversTypes['CollateralLock']>, "collateralLock", ParentType, ContextType, RequireFields<SubscriptioncollateralLockArgs, 'id' | 'subgraphError'>>;
  collateralLocks?: SubscriptionResolver<Array<ResolversTypes['CollateralLock']>, "collateralLocks", ParentType, ContextType, RequireFields<SubscriptioncollateralLocksArgs, 'skip' | 'first' | 'subgraphError'>>;
  marketplaceContract?: SubscriptionResolver<Maybe<ResolversTypes['MarketplaceContract']>, "marketplaceContract", ParentType, ContextType, RequireFields<SubscriptionmarketplaceContractArgs, 'id' | 'subgraphError'>>;
  marketplaceContracts?: SubscriptionResolver<Array<ResolversTypes['MarketplaceContract']>, "marketplaceContracts", ParentType, ContextType, RequireFields<SubscriptionmarketplaceContractsArgs, 'skip' | 'first' | 'subgraphError'>>;
  listing?: SubscriptionResolver<Maybe<ResolversTypes['Listing']>, "listing", ParentType, ContextType, RequireFields<SubscriptionlistingArgs, 'id' | 'subgraphError'>>;
  listings?: SubscriptionResolver<Array<ResolversTypes['Listing']>, "listings", ParentType, ContextType, RequireFields<SubscriptionlistingsArgs, 'skip' | 'first' | 'subgraphError'>>;
  _meta?: SubscriptionResolver<Maybe<ResolversTypes['_Meta_']>, "_meta", ParentType, ContextType, Partial<Subscription_metaArgs>>;
}>;

export interface TimestampScalarConfig extends GraphQLScalarTypeConfig<ResolversTypes['Timestamp'], any> {
  name: 'Timestamp';
}

export type TransferResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Transfer'] = ResolversParentTypes['Transfer']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  from?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  to?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  value?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type TransferSingleEventResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['TransferSingleEvent'] = ResolversParentTypes['TransferSingleEvent']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  operator?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  from?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  to?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  tokenId?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  value?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type TreasuryContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['TreasuryContract'] = ResolversParentTypes['TreasuryContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type VehicleResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['Vehicle'] = ResolversParentTypes['Vehicle']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  partner?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  vin?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  make?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  model?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  year?: Resolver<Maybe<ResolversTypes['BigInt']>, ParentType, ContextType>;
  blockNumber?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  blockTimestamp?: Resolver<ResolversTypes['BigInt'], ParentType, ContextType>;
  transactionHash?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type VehicleRegistryContractResolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['VehicleRegistryContract'] = ResolversParentTypes['VehicleRegistryContract']> = ResolversObject<{
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  address?: Resolver<ResolversTypes['Bytes'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type _Block_Resolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['_Block_'] = ResolversParentTypes['_Block_']> = ResolversObject<{
  hash?: Resolver<Maybe<ResolversTypes['Bytes']>, ParentType, ContextType>;
  number?: Resolver<ResolversTypes['Int'], ParentType, ContextType>;
  timestamp?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>;
  parentHash?: Resolver<Maybe<ResolversTypes['Bytes']>, ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type _Meta_Resolvers<ContextType = MeshContext, ParentType extends ResolversParentTypes['_Meta_'] = ResolversParentTypes['_Meta_']> = ResolversObject<{
  block?: Resolver<ResolversTypes['_Block_'], ParentType, ContextType>;
  deployment?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  hasIndexingErrors?: Resolver<ResolversTypes['Boolean'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type Resolvers<ContextType = MeshContext> = ResolversObject<{
  BigDecimal?: GraphQLScalarType;
  BigInt?: GraphQLScalarType;
  Bytes?: GraphQLScalarType;
  CollateralLock?: CollateralLockResolvers<ContextType>;
  Int8?: GraphQLScalarType;
  Listing?: ListingResolvers<ContextType>;
  MarketplaceContract?: MarketplaceContractResolvers<ContextType>;
  MockUSDCContract?: MockUSDCContractResolvers<ContextType>;
  Partner?: PartnerResolvers<ContextType>;
  PartnerManagerContract?: PartnerManagerContractResolvers<ContextType>;
  Query?: QueryResolvers<ContextType>;
  RegisteredAssetRouter?: RegisteredAssetRouterResolvers<ContextType>;
  RegistryRouterContract?: RegistryRouterContractResolvers<ContextType>;
  RoboshareToken?: RoboshareTokenResolvers<ContextType>;
  RoboshareTokensContract?: RoboshareTokensContractResolvers<ContextType>;
  Subscription?: SubscriptionResolvers<ContextType>;
  Timestamp?: GraphQLScalarType;
  Transfer?: TransferResolvers<ContextType>;
  TransferSingleEvent?: TransferSingleEventResolvers<ContextType>;
  TreasuryContract?: TreasuryContractResolvers<ContextType>;
  Vehicle?: VehicleResolvers<ContextType>;
  VehicleRegistryContract?: VehicleRegistryContractResolvers<ContextType>;
  _Block_?: _Block_Resolvers<ContextType>;
  _Meta_?: _Meta_Resolvers<ContextType>;
}>;

export type DirectiveResolvers<ContextType = MeshContext> = ResolversObject<{
  entity?: entityDirectiveResolver<any, any, ContextType>;
  subgraphId?: subgraphIdDirectiveResolver<any, any, ContextType>;
  derivedFrom?: derivedFromDirectiveResolver<any, any, ContextType>;
}>;

export type MeshContext = RoboshareProtocolTypes.Context & BaseMeshContext;


import { fileURLToPath } from '@graphql-mesh/utils';
const baseDir = pathModule.join(pathModule.dirname(fileURLToPath(import.meta.url)), '..');

const importFn: ImportFn = <T>(moduleId: string) => {
  const relativeModuleId = (pathModule.isAbsolute(moduleId) ? pathModule.relative(baseDir, moduleId) : moduleId).split('\\').join('/').replace(baseDir + '/', '');
  switch(relativeModuleId) {
    case ".graphclient/sources/RoboshareProtocol/introspectionSchema":
      return Promise.resolve(importedModule$0) as T;
    
    default:
      return Promise.reject(new Error(`Cannot find module '${relativeModuleId}'.`));
  }
};

const rootStore = new MeshStore('.graphclient', new FsStoreStorageAdapter({
  cwd: baseDir,
  importFn,
  fileType: "ts",
}), {
  readonly: true,
  validate: false
});

export const rawServeConfig: YamlConfig.Config['serve'] = undefined as any
export async function getMeshOptions(): Promise<GetMeshOptions> {
const pubsub = new PubSub();
const sourcesStore = rootStore.child('sources');
const logger = new DefaultLogger("GraphClient");
const cache = new (MeshCache as any)({
      ...({} as any),
      importFn,
      store: rootStore.child('cache'),
      pubsub,
      logger,
    } as any)

const sources: MeshResolvedSource[] = [];
const transforms: MeshTransform[] = [];
const additionalEnvelopPlugins: MeshPlugin<any>[] = [];
const roboshareProtocolTransforms = [];
const additionalTypeDefs = [] as any[];
const roboshareProtocolHandler = new GraphqlHandler({
              name: "RoboshareProtocol",
              config: {"endpoint":"http://localhost:8000/subgraphs/name/roboshare/protocol"},
              baseDir,
              cache,
              pubsub,
              store: sourcesStore.child("RoboshareProtocol"),
              logger: logger.child("RoboshareProtocol"),
              importFn,
            });
sources[0] = {
          name: 'RoboshareProtocol',
          handler: roboshareProtocolHandler,
          transforms: roboshareProtocolTransforms
        }
const additionalResolvers = [] as any[]
const merger = new(BareMerger as any)({
        cache,
        pubsub,
        logger: logger.child('bareMerger'),
        store: rootStore.child('bareMerger')
      })
const documentHashMap = {
        "fd47c4a360dd037c11569d9ff51e0bbd258b2adc5b8fb2d8d1e3a7f40e19ab08": GetAllVehiclesDocument,
"bdd8a61857887fd8aa8ac42d04f01d13c5437f6cfb59b7cdfc8c88f67f81adcc": GetVehiclesDocument
      }
additionalEnvelopPlugins.push(usePersistedOperations({
        getPersistedOperation(key) {
          return documentHashMap[key];
        },
        ...{}
      }))

  return {
    sources,
    transforms,
    additionalTypeDefs,
    additionalResolvers,
    cache,
    pubsub,
    merger,
    logger,
    additionalEnvelopPlugins,
    get documents() {
      return [
      {
        document: GetAllVehiclesDocument,
        get rawSDL() {
          return printWithCache(GetAllVehiclesDocument);
        },
        location: 'GetAllVehiclesDocument.graphql',
        sha256Hash: 'fd47c4a360dd037c11569d9ff51e0bbd258b2adc5b8fb2d8d1e3a7f40e19ab08'
      },{
        document: GetVehiclesDocument,
        get rawSDL() {
          return printWithCache(GetVehiclesDocument);
        },
        location: 'GetVehiclesDocument.graphql',
        sha256Hash: 'bdd8a61857887fd8aa8ac42d04f01d13c5437f6cfb59b7cdfc8c88f67f81adcc'
      }
    ];
    },
    fetchFn,
  };
}

export function createBuiltMeshHTTPHandler<TServerContext = {}>(): MeshHTTPHandler<TServerContext> {
  return createMeshHTTPHandler<TServerContext>({
    baseDir,
    getBuiltMesh: getBuiltGraphClient,
    rawServeConfig: undefined,
  })
}


let meshInstance$: Promise<MeshInstance> | undefined;

export const pollingInterval = null;

export function getBuiltGraphClient(): Promise<MeshInstance> {
  if (meshInstance$ == null) {
    if (pollingInterval) {
      setInterval(() => {
        getMeshOptions()
        .then(meshOptions => getMesh(meshOptions))
        .then(newMesh =>
          meshInstance$.then(oldMesh => {
            oldMesh.destroy()
            meshInstance$ = Promise.resolve(newMesh)
          })
        ).catch(err => {
          console.error("Mesh polling failed so the existing version will be used:", err);
        });
      }, pollingInterval)
    }
    meshInstance$ = getMeshOptions().then(meshOptions => getMesh(meshOptions)).then(mesh => {
      const id = mesh.pubsub.subscribe('destroy', () => {
        meshInstance$ = undefined;
        mesh.pubsub.unsubscribe(id);
      });
      return mesh;
    });
  }
  return meshInstance$;
}

export const execute: ExecuteMeshFn = (...args) => getBuiltGraphClient().then(({ execute }) => execute(...args));

export const subscribe: SubscribeMeshFn = (...args) => getBuiltGraphClient().then(({ subscribe }) => subscribe(...args));
export function getBuiltGraphSDK<TGlobalContext = any, TOperationContext = any>(globalContext?: TGlobalContext) {
  const sdkRequester$ = getBuiltGraphClient().then(({ sdkRequesterFactory }) => sdkRequesterFactory(globalContext));
  return getSdk<TOperationContext, TGlobalContext>((...args) => sdkRequester$.then(sdkRequester => sdkRequester(...args)));
}
export type GetAllVehiclesQueryVariables = Exact<{ [key: string]: never; }>;


export type GetAllVehiclesQuery = { vehicles: Array<Pick<Vehicle, 'id' | 'partner' | 'vin' | 'make' | 'model' | 'year' | 'blockNumber' | 'blockTimestamp' | 'transactionHash'>> };

export type GetVehiclesQueryVariables = Exact<{
  partner?: InputMaybe<Scalars['Bytes']['input']>;
}>;


export type GetVehiclesQuery = { vehicles: Array<Pick<Vehicle, 'id' | 'partner' | 'vin' | 'make' | 'model' | 'year' | 'blockNumber' | 'blockTimestamp' | 'transactionHash'>> };


export const GetAllVehiclesDocument = gql`
    query GetAllVehicles {
  vehicles(first: 25, orderBy: blockTimestamp, orderDirection: desc) {
    id
    partner
    vin
    make
    model
    year
    blockNumber
    blockTimestamp
    transactionHash
  }
}
    ` as unknown as DocumentNode<GetAllVehiclesQuery, GetAllVehiclesQueryVariables>;
export const GetVehiclesDocument = gql`
    query GetVehicles($partner: Bytes) {
  vehicles(
    first: 25
    orderBy: blockTimestamp
    orderDirection: desc
    where: {partner: $partner}
  ) {
    id
    partner
    vin
    make
    model
    year
    blockNumber
    blockTimestamp
    transactionHash
  }
}
    ` as unknown as DocumentNode<GetVehiclesQuery, GetVehiclesQueryVariables>;



export type Requester<C = {}, E = unknown> = <R, V>(doc: DocumentNode, vars?: V, options?: C) => Promise<R> | AsyncIterable<R>
export function getSdk<C, E>(requester: Requester<C, E>) {
  return {
    GetAllVehicles(variables?: GetAllVehiclesQueryVariables, options?: C): Promise<GetAllVehiclesQuery> {
      return requester<GetAllVehiclesQuery, GetAllVehiclesQueryVariables>(GetAllVehiclesDocument, variables, options) as Promise<GetAllVehiclesQuery>;
    },
    GetVehicles(variables?: GetVehiclesQueryVariables, options?: C): Promise<GetVehiclesQuery> {
      return requester<GetVehiclesQuery, GetVehiclesQueryVariables>(GetVehiclesDocument, variables, options) as Promise<GetVehiclesQuery>;
    }
  };
}
export type Sdk = ReturnType<typeof getSdk>;