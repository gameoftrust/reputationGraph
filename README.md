# ReputationGraph Contract

This contract is a decentralized endorsement system for trust scores between users. It allows users to endorse each other with a score, a confidence level, and a topic ID. The scores are stored on the Ethereum blockchain and can be queried to create a trust graph. The contract also supports EIP-712 signatures for off-chain signing and on-chain verification.

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Setting Up Roles](#setting-up-roles)
  - [Managing Metadata](#managing-metadata)
  - [Endorsing Users](#endorsing-users)
  - [Querying Scores](#querying-scores)
- [Events](#events)
- [Errors](#errors)

## Description

The `ReputationGraph` contract has the following features:

1. Role-based access control for administrative tasks and endorsement management.
2. Endorsement submission with EIP-712 signatures.
3. Querying scores to create a trust graph.

## Requirements

1. Solidity compiler version ^0.8.9.
2. OpenZeppelin Contracts for role-based access control.

## Installation

To use this contract in your project, you can either copy the source code or import it from a package manager such as NPM.

## Usage

### Setting Up Roles

Upon contract deployment, an admin and an endorser role will be set up. The admin is responsible for managing the contract's metadata, while the endorser is responsible for submitting endorsements.

### Managing Metadata

Admin can set a metadata URI using the `setMetadataURI` function, which will emit a `MetadataUpdated` event.

### Endorsing Users

Users with the endorser role can submit endorsements. Each endorsement consists of a `from` address, a `to` address, a timestamp, and an array of `RawScore` objects. Each `RawScore` object contains a topic ID, a score, and a confidence level. The endorsement must be signed using the EIP-712 standard. The `_endorse` function will save the endorsement data and emit a `Scored` event.

### Querying Scores

The contract provides two public view functions for querying scores:

1. `getScoresLength`: Returns the length of the scores array.
2. `getScores`: Returns a slice of the scores array based on the given `fromIndex` and `toIndex`.

## Events

1. `Scored`: Emitted when an endorsement is successfully saved. Contains the endorsement data.
2. `MetadataUpdated`: Emitted when the metadata URI is updated by the admin.

## Errors

The contract defines the following custom errors:

2. `NotSigner`: The signer of the endorsement is not the same as the `from` address in the endorsement.
3. `InvalidTimestamp`: The provided timestamp is earlier than the last endorsement timestamp.
