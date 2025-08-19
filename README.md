# Weather-Based Crop Insurance Smart Contract

An automated, oracle-driven crop insurance system built on Stacks blockchain using Clarity smart contracts. This system enables farmers to purchase parametric insurance policies that automatically pay out based on weather conditions without requiring traditional insurance adjusters.

## Features

- **Automated Payouts**: Claims are processed automatically based on oracle-verified weather data
- **Parametric Insurance**: Coverage based on measurable weather parameters (rainfall, temperature)
- **Oracle Integration**: Verified weather data from authorized oracles
- **Policy Management**: Purchase, cancel, and manage insurance policies
- **Transparent Operations**: All transactions and conditions recorded on blockchain

## Core Functions

### Policy Management

#### `purchase-policy`
Purchase a new crop insurance policy with customizable weather thresholds.

```clarity
(contract-call? .CropInsured purchase-policy 
  u1000000          ;; coverage-amount (micro-STX)
  "corn"            ;; crop-type  
  "Iowa-Farm-001"   ;; location
  u1000             ;; planting-date (block height)
  u1200             ;; harvest-date (block height)
  u50               ;; rainfall-min (mm)
  u200              ;; rainfall-max (mm) 
  u10               ;; temp-min (°C)
  u35               ;; temp-max (°C)
)
```

#### `file-claim`
File a claim for payout if weather conditions were met during growing season.

```clarity
(contract-call? .CropInsured file-claim u1) ;; policy-id
```

#### `cancel-policy`
Cancel an active policy before planting date (80% premium refund).

```clarity
(contract-call? .CropInsured cancel-policy u1) ;; policy-id
```

### Oracle Functions

#### `initialize-oracle`
Register an authorized weather data oracle (contract owner only).

```clarity
(contract-call? .CropInsured initialize-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `submit-weather-data`
Submit verified weather data for a specific location and date.

```clarity
(contract-call? .CropInsured submit-weather-data 
  "Iowa-Farm-001"   ;; location
  u1100             ;; date (block height)
  u75               ;; rainfall (mm)
  u28               ;; temperature (°C)
)
```

### Read-Only Functions

#### `get-policy`
Retrieve policy details by ID.

```clarity
(contract-call? .CropInsured get-policy u1)
```

#### `get-farmer-policies`
Get all policy IDs for a specific farmer.

```clarity
(contract-call? .CropInsured get-farmer-policies 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-weather-data`
Retrieve weather data for specific location and date.

```clarity
(contract-call? .CropInsured get-weather-data "Iowa-Farm-001" u1100)
```

#### `get-contract-stats`
View contract statistics (total policies, premiums, payouts).

```clarity
(contract-call? .CropInsured get-contract-stats)
```

## Policy Workflow

1. **Purchase**: Farmer calls `purchase-policy` with coverage details and weather thresholds
2. **Premium Payment**: Premium calculated and deducted automatically (5% of coverage + duration factors)
3. **Growing Season**: Oracle submits weather data during crop growing period
4. **Claim Processing**: After harvest date, farmer calls `file-claim`
5. **Automatic Payout**: Contract checks weather conditions and pays out coverage if thresholds exceeded

## Weather Conditions

Policies pay out if ANY of these conditions are met during the growing season:
- Rainfall below minimum threshold (drought)
- Rainfall above maximum threshold (flooding) 
- Temperature below minimum threshold (frost)
- Temperature above maximum threshold (heat stress)

## Premium Calculation

```
Premium = (Coverage Amount × 5%) × Duration Factor
Duration Factor = 100% for ≤180 days, 150% for >180 days
```

## Testing

Run the test suite to verify contract functionality:

```bash
npm install
npm test
```

Check contract syntax and analysis:

```bash
clarinet check
```

## Deployment

1. Configure deployment settings in `settings/Devnet.toml`
2. Deploy to devnet:
```bash
clarinet deployments apply -e devnet
```

## Oracle Requirements

- Oracles must be authorized by contract owner
- Minimum reputation score of 50 required
- Weather data submissions require oracle signature
- Data includes location, date, rainfall (mm), and temperature (°C)

## Error Codes

- `ERR_NOT_AUTHORIZED (100)`: Caller not authorized for this action
- `ERR_POLICY_NOT_FOUND (101)`: Policy ID does not exist
- `ERR_INSUFFICIENT_FUNDS (102)`: Insufficient balance for premium
- `ERR_POLICY_EXPIRED (103)`: Policy is no longer active
- `ERR_ALREADY_CLAIMED (104)`: Claim already processed
- `ERR_CONDITIONS_NOT_MET (105)`: Weather conditions don't qualify for payout
- `ERR_INVALID_ORACLE (106)`: Oracle not authorized or reputation too low
- `ERR_POLICY_ACTIVE (107)`: Cannot cancel active policy

## Contract Address

Deploy the contract and update this section with the deployed contract address.

## License

MIT License - see LICENSE file for details.
