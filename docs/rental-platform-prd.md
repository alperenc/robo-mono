# Roboshare Rental Platform PRD

Status: Draft
Date: March 12, 2026
Owner: Product + Protocol

## 1. Summary

This document defines the product requirements for a Turo-like vehicle rental platform built on top of the Roboshare Protocol.

The core idea is:

- vehicles are created and registered through `VehicleRegistry`
- each vehicle remains a protocol asset with an `assetId`
- the rental platform operates the consumer marketplace, booking engine, trip lifecycle, claims, and host tooling
- Roboshare remains the onchain source of truth for asset registration, partner authorization, tokenization, investor ownership, earnings distribution, and settlement

This is explicitly a two-layer product:

- offchain rental operations layer
- onchain asset and investor layer

That split matches the current codebase. The existing protocol supports vehicle registration, token pool creation, investor purchases, earnings distribution, and settlement. It does not currently support booking, trip management, renter identity, claims, or rental escrow.

## 2. Problem

Today, Roboshare can register vehicles and monetize them as tokenized assets, but it does not yet provide the operating product that actually generates rental demand and trip revenue.

Without a rental marketplace:

- partners can tokenize vehicles, but cannot rent them through the product
- investors can buy revenue exposure, but cannot see a native operational funnel that drives earnings
- the protocol relies on partner-submitted revenue instead of platform-recorded bookings and completed trips

The missing product is a rental marketplace that turns a registered vehicle into an active commercial asset with real-world utilization.

## 3. Goals

### Primary goals

- Enable every eligible vehicle created via `VehicleRegistry` to be listed for rent in a consumer marketplace.
- Create a clean operating model where booking and trip events ultimately translate into protocol earnings for the corresponding `assetId`.
- Give partners a host-grade fleet operations tool for pricing, availability, booking management, check-in/out, maintenance, and claims.
- Give renters a full booking and trip experience comparable to a mainstream car-sharing marketplace.
- Give investors transparent visibility into rental performance, utilization, revenue, and earnings distribution by asset.

### Secondary goals

- Use `assetId` as the canonical key across protocol and platform systems.
- Keep rental operations flexible enough to evolve without forcing all booking logic onchain.
- Make revenue posted to `Treasury.distributeEarnings` auditable against platform accounting.

## 4. Non-goals

- Fully onchain bookings in the MVP
- Fully onchain trip-state management in the MVP
- Replacing mainstream KYC, driver verification, payment processing, or insurance systems with protocol contracts
- Building a general-purpose property management system for all future asset classes in the first release
- Trustless telematics enforcement in the MVP

## 5. Product principles

- `assetId` is the canonical identifier across all systems.
- Operational workflows remain offchain unless onchain execution materially improves trust, settlement, or portability.
- Revenue posted into the protocol must be derived from reconciled platform accounting, not loose manual inputs.
- Hosts, renters, and investors each need first-class product surfaces.
- Protocol state and rental state are related but not identical.

## 6. Current protocol baseline

The current codebase already provides:

- partner authorization through `PartnerManager`
- vehicle registration through `VehicleRegistry`
- one asset token plus one revenue token per vehicle through `RoboshareTokens`
- primary and secondary revenue-token market flows through `Marketplace`
- collateral, earnings, and settlement flows through `Treasury`
- indexed views of vehicles, pools, listings, trades, and earnings through the subgraph

The current codebase does not provide:

- rental listings
- availability calendars
- booking requests and confirmations
- renter accounts and driver verification
- trip check-in or check-out
- cancellation policies and refund execution
- security deposit management for renters
- damage claims and dispute resolution
- platform-level revenue reconciliation by trip

## 7. Product scope

The rental platform will include four major product surfaces:

1. Consumer renter app
2. Host and fleet operations app
3. Investor analytics and protocol insights app
4. Internal operations and risk tooling

## 8. Users and roles

### Partner / Host

An authorized protocol partner that owns or operates vehicles and wants to rent them out and optionally tokenize their future cash flow.

### Renter

A consumer who discovers, books, and uses a vehicle for a trip.

### Investor

A protocol user who buys or trades revenue tokens and expects transparent operating performance and earnings distributions.

### Platform Ops / Admin

An internal operator responsible for risk controls, support, claims, moderation, payout reconciliation, and exceptions handling.

## 9. Product architecture

### 9.1 Protocol-owned responsibilities

The Roboshare Protocol remains the source of truth for:

- vehicle asset registration
- partner authorization
- asset lifecycle at the protocol level
- revenue-token economics
- investor ownership and transfers
- earnings distribution
- settlement and liquidation

### 9.2 Platform-owned responsibilities

The rental platform owns:

- vehicle merchandising and search
- booking and availability logic
- pricing and promotions
- renter onboarding and verification
- payment authorization and capture
- security deposit handling
- check-in and check-out workflows
- mileage, fuel, damage, and incident records
- cancellations, refunds, and disputes
- accounting and reconciliation
- revenue batching into the protocol

### 9.3 Integration model

The platform will ingest onchain events for:

- partner authorization
- vehicle registration
- metadata updates
- revenue pool creation
- earnings distributions
- settlement and retirement

The platform will maintain an offchain operating ledger keyed by `assetId` and periodically reconcile net distributable revenue into the protocol.

## 10. Core domain model

New offchain entities required:

- `RentalListing`
- `VehicleOperationalStatus`
- `AvailabilityCalendar`
- `PricingRule`
- `Booking`
- `BookingCharge`
- `SecurityDeposit`
- `Trip`
- `PickupReport`
- `ReturnReport`
- `MileageRecord`
- `DamageClaim`
- `Refund`
- `PayoutBatch`
- `RenterProfile`
- `HostProfile`
- `RevenueLedgerEntry`

Each entity must include `assetId` as a required foreign key where applicable.

## 11. State models

### 11.1 Platform vehicle state

- `onboarding`
- `listed`
- `booked`
- `in_trip`
- `inspection`
- `available`
- `maintenance`
- `delisted`

This state model is offchain and operational.

### 11.2 Booking state

- `draft`
- `payment_authorized`
- `confirmed`
- `cancelled`
- `checked_in`
- `in_trip`
- `completed`
- `no_show`
- `late_return`
- `disputed`
- `refunded`

### 11.3 Protocol state relationship

Protocol `AssetStatus` remains separate:

- `Pending`
- `Active`
- `Earning`
- `Suspended`
- `Expired`
- `Retired`

Example:

- a vehicle can be protocol `Earning` while platform `maintenance`
- a vehicle can be protocol `Active` while platform `booked`
- a vehicle should not be renter-visible if protocol state is not operational

## 12. User journeys

### 12.1 Host onboarding journey

1. Partner is authorized in `PartnerManager`.
2. Partner registers vehicle through `VehicleRegistry`.
3. Platform ingests the new `assetId`.
4. Host completes rental setup:
   - photos
   - description
   - pickup/dropoff settings
   - house rules
   - pricing rules
   - calendar availability
   - delivery options
5. Host optionally launches tokenization and a revenue pool.
6. Vehicle becomes bookable in the consumer marketplace.

### 12.2 Renter booking journey

1. Renter searches by location and dates.
2. Renter views vehicle PDP.
3. Renter completes identity and driver verification.
4. Platform prices the trip and authorizes payment plus deposit.
5. Booking is confirmed.
6. Renter checks in, starts trip, and completes return flow.
7. Final charges and refunds are reconciled.
8. Net recognized revenue is recorded against the vehicle `assetId`.

### 12.3 Investor journey

1. Investor discovers an asset and its rental performance.
2. Investor buys revenue tokens through the existing Roboshare market flow.
3. Investor monitors occupancy, revenue, disputes, downtime, and realized earnings.
4. Investor claims earnings through the existing protocol flow.

## 13. Functional requirements

### 13.1 Consumer marketplace

The renter-facing product must support:

- search by location, date range, price, vehicle type, delivery, instant book, EV, seats, and features
- vehicle detail pages with images, rules, fees, host information, availability, and trip estimate
- account creation and wallet-independent rental flows
- identity verification and driver-license verification
- booking checkout with tax, fees, deposit, and protection-plan pricing
- booking confirmation, trip reminders, and trip management
- cancellation and refund visibility
- support and incident reporting

### 13.2 Host operations

The host app must support:

- import or sync newly registered protocol vehicles
- rental setup completion for each `assetId`
- price/day, discounts, dynamic pricing, minimum trip length, and add-ons
- blackout dates and maintenance holds
- booking review and auto-accept rules
- pickup, handoff, and return workflows with photo capture
- mileage, fuel, charge level, and condition reports
- claims and dispute initiation
- earnings, payout, and utilization reporting
- manual controls to delist or suspend a vehicle from rental availability

### 13.3 Investor experience

The investor app must support:

- current protocol data from pools, listings, earnings, and settlement
- operational KPIs tied to each `assetId`
- utilization rate
- completed trips
- booked days
- gross booking value
- net recognized revenue
- cancellation rate
- maintenance downtime
- dispute rate
- time from trip completion to earnings distribution

### 13.4 Internal operations

Ops tooling must support:

- manual booking overrides
- refunds and charge adjustments
- chargeback handling
- dispute workflow management
- fraud and abuse review
- vehicle safety takedown
- claims adjudication
- payout holds
- reconciliation monitoring

## 14. Revenue and accounting specification

### 14.1 Revenue policy

The platform must define a canonical revenue number per asset for protocol posting.

Recommended definition:

`recognized_revenue = completed_trip_rental_revenue - refunds - chargebacks - taxes - pass_through_insurance_costs - waived_fees`

This recognized revenue is the input to protocol earnings distribution.

### 14.2 Revenue ledger

The platform must maintain an immutable ledger per `assetId` with:

- booking amount
- discount amount
- taxes
- fees
- protection-plan revenue and cost treatment
- refund amount
- chargeback amount
- final recognized revenue
- booking completion timestamp
- distribution batch ID

### 14.3 Distribution cadence

MVP recommendation:

- daily internal reconciliation
- weekly or monthly batched calls to `Treasury.distributeEarnings`

The cadence should be configurable by partner or platform policy.

### 14.4 Distribution guardrails

Before posting earnings, the platform must verify:

- asset exists and is protocol-operational
- no duplicate revenue posting for the same ledger entries
- reconciled net revenue is non-negative
- adjustments are captured for cancellations, refunds, and disputes

## 15. Payments and escrow

### 15.1 MVP

Use an offchain payment processor for:

- card authorization
- capture
- refunds
- deposit holds
- dispute workflows

Do not force renter checkout through an onchain wallet in the MVP.

### 15.2 Future optional onchain rails

Phase 2 may introduce a dedicated rental escrow contract for:

- deposit holds in stablecoins
- programmable refunds
- onchain host payouts

This should be treated as an optional extension, not an MVP blocker.

## 16. Metadata strategy

`dynamicMetadataURI` should be used for public, non-latency-sensitive asset metadata such as:

- latest photos
- odometer snapshots
- maintenance summary
- public performance summary
- availability summary window

It should not be used as the primary operational database for:

- live calendar availability
- booking lifecycle state
- payment or dispute state
- telematics streams

## 17. Trust and safety requirements

The platform must support:

- identity verification
- driver-license verification
- sanctions and fraud screening where required
- safety incident reporting
- claims evidence capture
- host and renter suspension controls
- manual administrative override

## 18. Compliance and legal requirements

The product must be designed to support:

- jurisdiction-aware host and renter terms
- tax handling
- privacy controls for renter identity and trip data
- document retention for claims and disputes
- clear separation between investment disclosures and renter marketplace communications

Legal review is required before launch for:

- securities-adjacent disclosure overlap between investor and rental products
- partner classification and payout structure
- insurance and protection-plan wording
- deposit handling

## 19. Reporting requirements

### 19.1 Host metrics

- active vehicles
- utilization
- completed trips
- gross bookings
- recognized revenue
- cancellation rate
- claims rate
- average trip length
- time to payout

### 19.2 Investor metrics

- asset revenue trend
- distribution frequency
- token yield vs target yield
- occupancy trend
- downtime trend
- claims impact
- settlement status

### 19.3 Platform metrics

- search-to-book conversion
- authorization success rate
- booking completion rate
- refund rate
- dispute rate
- take rate
- time from trip completion to earnings posting

## 20. Technical requirements

### 20.1 Services

MVP services required:

- protocol event ingester
- vehicle sync service
- booking engine
- pricing and availability service
- renter identity service
- payment orchestration service
- trip operations service
- claims service
- accounting and reconciliation service
- protocol earnings distributor
- investor analytics API

### 20.2 Data requirements

- all operational records must be queryable by `assetId`
- all revenue postings must be traceable to booking and ledger records
- all manual overrides must be audit logged
- all claims and dispute actions must be time-stamped and attributable

### 20.3 Reliability

The platform must support:

- idempotent protocol posting
- replayable event ingestion
- reconciliation re-runs
- partial outage recovery for payment, booking, and distribution systems

## 21. Contract and protocol change recommendations

These are not all required for MVP, but they should be planned:

### 21.1 Recommended near-term changes

- Restrict `updateVehicleMetadata` so only the owning partner can update a vehicle, not any authorized partner.
- Add revenue attestation metadata to earnings distributions.
- Add explicit integration hooks for batch revenue posting provenance.

### 21.2 Optional later changes

- `RentalEscrow` contract for stablecoin deposit flows
- `RevenueAttestor` contract or signed attestation registry
- protocol-native booking commitment proofs if strong portability becomes necessary

## 22. Phased delivery plan

### Phase 0: Foundations

- ingest protocol vehicles into platform database
- create host-facing rental setup flow for registered vehicles
- define accounting policy for recognized revenue
- establish payment processor, KYC, and support tooling

Exit criteria:

- any newly registered vehicle can be synced into host setup within minutes
- each synced vehicle is keyed by `assetId`

### Phase 1: MVP rental marketplace

- renter search and PDP
- booking checkout
- verification
- host pricing and availability
- booking confirmation
- trip check-in and check-out
- refunds and cancellations
- weekly or monthly earnings batching into Treasury

Exit criteria:

- vehicle with a valid `assetId` can be booked end to end
- completed trip revenue can be reconciled and posted into protocol earnings

### Phase 2: Operations and investor transparency

- richer investor dashboards
- host utilization and claims dashboards
- dispute tooling
- telematics and condition-report integrations
- signed revenue batch attestations

Exit criteria:

- investors can map protocol earnings to operating performance with minimal manual interpretation

### Phase 3: Advanced protocol integrations

- optional onchain rental escrow
- optional programmable deposit release
- stronger proof links between offchain ledger and onchain earnings events

Exit criteria:

- selected rental financial flows can settle through dedicated onchain rails without breaking core UX

## 23. Success metrics

### Marketplace metrics

- booking conversion rate
- repeat renter rate
- average booking value
- host activation rate

### Operational metrics

- fleet utilization
- completed-trip rate
- cancellation rate
- claims rate
- mean time to resolution

### Protocol-linked metrics

- percentage of active registered vehicles that become rentable
- percentage of rentable vehicles that generate posted earnings
- time from completed trip to `distributeEarnings`
- variance between platform recognized revenue and protocol-posted revenue

## 24. Risks

- misalignment between offchain accounting and protocol earnings
- user confusion between rental ownership and investment ownership
- legal overlap between marketplace operations and investment messaging
- operational complexity around claims, insurance, and chargebacks
- partner misuse of manual revenue posting if reconciliation controls are weak
- stale or misleading investor metrics if platform and protocol data pipelines drift

## 25. Open questions

- Should all protocol-registered vehicles be eligible for rental by default, or should rental eligibility require an extra host setup approval step?
- Should the platform support instant book only, approval-based booking only, or both?
- How should insurance and protection-plan economics be treated in recognized revenue?
- How frequently should earnings be posted for high-volume assets?
- Which investor metrics belong onchain, if any, versus remaining purely offchain?
- When should a protocol asset be moved from `Active` to `Earning` in relation to real booking activity?

## 26. MVP recommendation

The recommended MVP is:

- offchain booking engine
- offchain payments and deposits
- offchain trip and claims operations
- onchain asset registration and investor markets
- batched protocol earnings posting from reconciled trip revenue

This gives Roboshare a realistic path to market without forcing the rental product to inherit unnecessary onchain complexity too early.
