# 🌾 Weather-Based Crop Insurance Smart Contract

An automated, oracle-driven crop insurance system built on Stacks blockchain using Clarity smart contracts. This system enables farmers to purchase parametric insurance policies that automatically pay out based on weather conditions without requiring traditional insurance adjusters.

## 🚀 Features

### Core Insurance Features
- **🤖 Automated Payouts**: Claims are processed automatically based on oracle-verified weather data
- **📊 Parametric Insurance**: Coverage based on measurable weather parameters (rainfall, temperature)
- **🔗 Oracle Integration**: Verified weather data from authorized oracles
- **📋 Policy Management**: Purchase, cancel, and manage insurance policies
- **🔍 Transparent Operations**: All transactions and conditions recorded on blockchain

### 🆕 NEW: Premium Discount Loyalty System
- **🏆 Loyalty Rewards**: Multi-season farmers earn progressive premium discounts
- **💰 Smart Discounts**: Up to 20% off premiums for consecutive claim-free seasons
- **🥉 Tier System**: Bronze, Silver, Gold, and Platinum loyalty tiers
- **📈 Performance Tracking**: Comprehensive farmer history and statistics
- **🎯 Incentive Alignment**: Reward responsible farming practices

## 💰 Premium Discount Structure

| Consecutive Seasons (No Claims) | Discount | Loyalty Tier |
|:--------------------------------:|:--------:|:------------:|
| 1 Season | 0% | 🥉 Bronze |
| 2+ Seasons | 5% | 🥉 Bronze |
| 3-4 Seasons | 10% | 🥈 Silver |
| 5-7 Seasons | 15% | 🥇 Gold |
| 8+ Seasons | 20% | 💎 Platinum |

> **Note**: Any filed claim resets the discount to 0% and consecutive seasons counter

## 📋 Core Functions

### Policy Management

#### `purchase-policy`
Purchase a new crop insurance policy with customizable weather thresholds and automatic discount application.

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

### 🆕 Loyalty System Functions

#### `get-farmer-loyalty-info`
Retrieve comprehensive loyalty information for a farmer.

```clarity
(contract-call? .CropInsured get-farmer-loyalty-info 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

**Returns:**
```clarity
{
  consecutive-seasons: u3,
  total-policies: u5,
  total-claims: u0,
  last-policy-season: u2024,
  discount-percentage: u10,
  loyalty-tier: "silver"
}
```

#### `get-farmer-discount-percentage`
Get the current discount percentage for a specific farmer.

```clarity
(contract-call? .CropInsured get-farmer-discount-percentage 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-loyalty-statistics`
View loyalty program statistics (total farmers with discounts).

```clarity
(contract-call? .CropInsured get-loyalty-statistics)
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
View enhanced contract statistics including loyalty program metrics.

```clarity
(contract-call? .CropInsured get-contract-stats)
```

**Enhanced response now includes:**
```clarity
{
  total-policies: u125,
  total-premiums: u5000000,
  total-payouts: u2500000,
  contract-balance: u2500000,
  farmers-with-discounts: u34  ;; NEW: farmers currently eligible for discounts
}
```

## 🔄 Policy Workflow

1. **📏 Purchase**: Farmer calls `purchase-policy` with coverage details and weather thresholds
2. **💳 Premium Calculation**: 
   - Base premium calculated (5% of coverage + duration factors)
   - 🆕 **Loyalty discount applied automatically** based on farmer history
3. **💰 Premium Payment**: Discounted premium deducted automatically 
4. **🌱 Growing Season**: Oracle submits weather data during crop growing period
5. **🔍 Claim Processing**: After harvest date, farmer calls `file-claim`
6. **💸 Automatic Payout**: Contract checks weather conditions and pays coverage if thresholds exceeded
7. **📊 Loyalty Update**: Farmer's consecutive seasons and discount eligibility updated

## 🌦️ Weather Conditions

Policies pay out if ANY of these conditions are met during the growing season:
- 🌧️ Rainfall below minimum threshold (drought)
- 🌊 Rainfall above maximum threshold (flooding) 
- ❄️ Temperature below minimum threshold (frost)
- 🔥 Temperature above maximum threshold (heat stress)

## 💰 Premium Calculation

### Base Premium Formula
```
Premium = (Coverage Amount × 5%) × Duration Factor × (1 - Discount Percentage)
Duration Factor = 100% for ≤180 days, 150% for >180 days
```

### 🆕 Example with Loyalty Discount
```
Farmer: John (Silver tier - 3 consecutive seasons, no claims)
Coverage: 1,000,000 micro-STX
Duration: 120 days
Base Premium: 50,000 micro-STX (5% of coverage)
Loyalty Discount: 10% (Silver tier)
Final Premium: 45,000 micro-STX (10% savings!)
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
- `ERR_INVALID_DISCOUNT (108)`: 🆕 Invalid discount percentage

## 🎯 Benefits of the Loyalty System

### For Farmers 💚
- **Lower Insurance Costs**: Significant savings for responsible farming
- **Predictable Premiums**: Clear discount structure based on performance
- **Long-term Value**: Rewards for building relationship with platform
- **Risk Management Incentive**: Encourages better farming practices

### For the Protocol 📈
- **Customer Retention**: Farmers incentivized to stay on platform
- **Risk Reduction**: Better farmers = fewer payouts
- **Sustainable Growth**: Long-term customer relationships
- **Competitive Advantage**: Unique value proposition in crop insurance

## 📊 Smart Contract Architecture

The loyalty system integrates seamlessly with existing functionality:

- **Data Storage**: New `farmer-loyalty` map tracks performance metrics
- **Automatic Updates**: Loyalty status updated with each policy purchase/claim
- **Backward Compatible**: No breaking changes to existing functions
- **Gas Efficient**: Minimal computational overhead

## 🏆 Roadmap Features

Future enhancements could include:
- 🌐 Multi-crop discount bonuses
- 🤝 Community farmer pools
- 📱 Mobile loyalty dashboard
- 🎁 NFT rewards for top-tier farmers

## Contract Address

Deploy the contract and update this section with the deployed contract address.

## License

MIT License - see LICENSE file for details.

---

**Built with 💚 for the farming community on Stacks blockchain**
