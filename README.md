# Tokenized Decentralized Outdoor Shovel Networks (TDOSN)

A blockchain-based system for managing, sharing, and optimizing outdoor shovels through smart contracts on the Stacks blockchain.

## Overview

TDOSN revolutionizes shovel management through five interconnected smart contracts that handle every aspect of shovel lifecycle management, from blade maintenance to community sharing coordination.

## Smart Contracts

### 1. Blade Sharpness Contract (`blade-sharpness.clar`)
- Monitors shovel blade condition and sharpness levels
- Tracks maintenance history and requirements
- Issues alerts for blade maintenance needs
- Manages sharpness scoring system (0-100 scale)

### 2. Handle Integrity Contract (`handle-integrity.clar`)
- Tracks wooden handle condition and structural integrity
- Monitors wear patterns and stress points
- Manages replacement scheduling and notifications
- Handles integrity scoring system (0-100 scale)

### 3. Sharing Coordination Contract (`sharing-coordination.clar`)
- Organizes shovel lending for community projects
- Manages booking and reservation system
- Tracks usage history and user ratings
- Handles dispute resolution for shared shovels

### 4. Storage Management Contract (`storage-management.clar`)
- Handles seasonal shovel protection and organization
- Manages storage location assignments
- Tracks environmental conditions and protection status
- Coordinates storage facility maintenance

### 5. Usage Optimization Contract (`usage-optimization.clar`)
- Provides digging technique guidance and efficiency tips
- Tracks usage patterns and performance metrics
- Manages efficiency scoring and recommendations
- Handles technique certification system

## Features

- **Tokenized Ownership**: Each shovel is represented as a unique token
- **Condition Monitoring**: Real-time tracking of shovel condition metrics
- **Community Sharing**: Decentralized lending and borrowing system
- **Maintenance Scheduling**: Automated alerts and maintenance coordination
- **Performance Analytics**: Usage optimization and efficiency tracking
- **Seasonal Management**: Automated storage and protection protocols

## Getting Started

### Prerequisites
- Stacks blockchain node access
- Clarity development environment
- Node.js and npm for testing

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts to Stacks testnet

### Testing

The project includes comprehensive Vitest-based tests for all contracts:

\`\`\`bash
npm test
\`\`\`

## Contract Architecture

Each contract operates independently without cross-contract calls, ensuring modularity and gas efficiency. The system uses a event-driven architecture where contracts emit events that can be monitored by off-chain services.

## Token Economics

- **SHOVEL Tokens**: Represent individual shovel ownership
- **SHARP Tokens**: Earned through proper blade maintenance
- **HANDLE Tokens**: Earned through handle care and replacement
- **SHARE Tokens**: Earned through community sharing participation
- **STORE Tokens**: Earned through proper storage management
- **OPTIMIZE Tokens**: Earned through efficient usage patterns

## Contributing

Please read the PR details file for contribution guidelines and development standards.

## License

MIT License - See LICENSE file for details

## Support

For technical support and questions, please open an issue in the repository.
