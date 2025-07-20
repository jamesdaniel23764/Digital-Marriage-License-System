# Digital Marriage License System

A comprehensive blockchain-based marriage license management system built on Stacks using Clarity smart contracts.

## System Overview

This system digitizes the entire marriage license process from application to permanent record keeping, ensuring transparency, security, and immutability of marriage records.

## Architecture

The system consists of 5 interconnected smart contracts:

### 1. Application Processing Contract (`application-processor.clar`)
- Manages marriage license applications
- Validates applicant information
- Tracks application status
- Handles application fees

### 2. Ceremony Scheduling Contract (`ceremony-scheduler.clar`)
- Coordinates wedding ceremony appointments
- Manages city hall availability
- Handles scheduling conflicts
- Tracks ceremony bookings

### 3. Officiant Verification Contract (`officiant-verifier.clar`)
- Validates officiant credentials
- Manages officiant registry
- Tracks officiant certifications
- Handles authorization levels

### 4. Certificate Issuance Contract (`certificate-issuer.clar`)
- Generates official marriage certificates
- Links applications to ceremonies
- Validates all prerequisites
- Issues unique certificate IDs

### 5. Record Maintenance Contract (`record-keeper.clar`)
- Maintains permanent marriage registry
- Provides record lookup functionality
- Handles record amendments
- Ensures data integrity

## Key Features

- **Immutable Records**: All marriage records are permanently stored on blockchain
- **Automated Validation**: Smart contracts ensure all requirements are met
- **Transparent Process**: Public verification of marriage status
- **Secure Authentication**: Cryptographic proof of identity
- **Efficient Processing**: Streamlined digital workflow

## Data Flow

1. **Application**: Couples submit applications through the application processor
2. **Scheduling**: Approved applications can schedule ceremonies
3. **Verification**: Officiants are verified before performing ceremonies
4. **Ceremony**: Ceremonies are conducted and recorded
5. **Certification**: Official certificates are issued
6. **Registry**: Records are permanently stored in the registry

## Error Codes

- `u100`: Invalid input parameters
- `u101`: Unauthorized access
- `u102`: Application not found
- `u103`: Insufficient payment
- `u104`: Schedule conflict
- `u105`: Invalid officiant
- `u106`: Prerequisites not met
- `u107`: Record already exists
- `u108`: Invalid certificate
- `u109`: System maintenance mode

## Getting Started

1. Install dependencies: `npm install`
2. Run tests: `npm test`
3. Deploy contracts: `clarinet deploy`

## Testing

The system includes comprehensive tests covering:
- Contract deployment
- Application processing
- Ceremony scheduling
- Officiant verification
- Certificate issuance
- Record maintenance
- Error handling
- Edge cases

## Security Considerations

- All sensitive operations require proper authorization
- Input validation prevents malicious data
- State changes are atomic and consistent
- Access controls protect administrative functions
