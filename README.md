# HigherOrLower Betting Game Contract - README
## Overview

##Contract address:
0x5b7199b4301E8f9290aa30fAbee5249Ca8dc6B06

The HigherOrLower contract is a decentralized betting game built in Solidity that allows players to bet on whether the next randomly drawn card will be higher, equal, or lower than the previous card. The game incorporates Chainlink VRF (Verifiable Random Function) to generate a secure random number for the card draws.

In addition to the players, there are investors (owners) who contribute funds to the game, and their investment is proportional to their share of the winnings when a player loses their bet. The owners also benefit by receiving a percentage of the player's bet when the player loses.

The CEO of the game is responsible for withdrawing a 10% commission of the total bet amount when a player loses. Owners are able to withdraw their share of the funds, provided they maintain a minimum balance to continue playing.

## Key Features:
 **1. Player Bets:** Players bet on whether the next card will be higher, lower, or equal to the previous one.

**2. Owner Investments:** Owners can invest in the game. Their share of the investment determines their share of the winnings when the player loses.

**3. Chainlink VRF:** Random number generation for the card draw using Chainlink's Verifiable Random Function (VRF).

**4. Payouts:** If the player wins, they get double their bet amount. If the player loses, the bet amount is distributed proportionally to the owners and the CEO.

**5. CEO Commission:** The CEO receives a 10% commission on each bet lost by the player.

**6. Owner Withdrawal:** Owners can withdraw their balance, provided they keep at least 1 ether in the contract.

## Game Workflow

**1. Investing in the Game**: Owners can invest in the game by sending at least 1 ether to the contract.
    The maximum number of owners allowed is 5. If the number of owners exceeds 5, new investments will be rejected.
    Owners’ balances are tracked, and their share of the winnings depends on how much they have invested.

**2. Placing a Bet:** Players can place a bet on whether the next card will be higher, equal, or lower than the previous one.
    The minimum bet is 0.5 ether, and the maximum bet depends on the total investment of the owners.
    The bet state transitions from OPEN to ONGAME when a player places their bet.

**3. Random Card Draw:**
    The contract uses Chainlink VRF to request a random number, which determines the next card.
    The card number is between 0 and 9.
    The game checks if the player’s bet is correct:
        If the player wins, they receive double their bet amount.
        If the player loses, the bet amount is distributed to the owners proportionally to their investment.

**4. Payout and Owner Distribution:**
If the player wins, the bet amount is doubled and sent to the player.
    If the player loses, the bet amount is distributed to the owners:
        The CEO receives 10% of the bet amount.
        The remaining 90% is distributed among the owners proportionally to their investment in the game.
    The contract ensures that each owner maintains at least 1 ether to continue participating in the game.

**5. Owner Withdrawals:**
 Owners can withdraw their balance, but they must ensure they leave at least 1 ether to remain eligible to play future rounds.
    The contract enforces withdrawal limits based on the owners' balances.

**6. CEO Withdrawals:**
The CEO can withdraw their 10% commission from the total bet amount at any time.
    Only the CEO can withdraw these funds.

## Functions

```bash
invest()
```

Allows a user to invest in the game by sending ether. The amount must be at least INVEST_AMOUNT (1 ether).

```bash
bet(uint256 bet_player)
```

Allows a player to place a bet on whether the next card will be higher, equal, or lower than the previous card. The bet must be between the MIN_BET and the calculated MaxBet.


```bash
setMaxBet()
```
Sets the maximum allowable bet amount based on the current total investment from the owners.

```bash
checkUpkeep(bytes memory checkData)
```
Checks if the upkeep conditions are met (e.g., time has passed, the game is open, there are players and sufficient balance).

```bash
performUpkeep(bytes calldata performData)
```
Triggered by the Chainlink Automation service to initiate the VRF request and determine the next card draw.

```bash
fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
```


Called by the Chainlink VRF to process the random number and determine the outcome of the game.

```bash
WinnerWithdraw()
```

Withdraws the doubled bet amount to the player if they win.
```bash
PayBet()
```
Distributes the bet amount to the owners and subtracts the owner's share if they lose the bet. Also ensures owners' balances are maintained correctly.
```bash
ceoWithdraw(uint256 amount_toWithdraw)
```

Allows the CEO to withdraw their 10% commission from the total bet amount.
```bash
OwnerWithdraw(uint256 amount_toWithdraw)
```
Allows owners to withdraw a portion of their balance, ensuring they leave at least 1 ether in the contract.
```bash
getOwnerBalance()
```
Returns the balance of the caller (owner).
```bash
getPreviousCard()
```
Returns the value of the previous card drawn.
```bash
getOwners(uint256 indexOwners)
```

Returns the address of an owner at a specific index.
```bash
getBet_State()
```

Returns the current state of the game (OPEN, CLOSED, CALCULATING, or ONGAME).
```bash
getBet()
```

Returns the current bet type (LOW, EQUAL, HIGH).
```bash
getMaxtoBet()
```

Returns the maximum bet allowed.
```bash
getPlayer()
```

Returns the address of the player who placed the current bet.
```bash
getBetAmount()
```

Returns the current bet amount.
```bash
getCEO()
```

Returns the address of the CEO.

## Error Handling

The contract includes a variety of custom error messages to help handle incorrect actions:

HigherOrLower_IncorrectInvestmentAmount(): Raised if an owner invests less than the minimum required amount.

   HigherOrLower_NotEnoughFundsToBet(): Raised if a player tries to bet less than the minimum or more than the maximum allowed.

   HigherOrLower_GAME_NOT_OPEN(): Raised if a bet is placed when the game is not open.

  HigherOrLower_TooMuchFundsToBet(): Raised if a player tries to bet more than the maximum allowed.

HigherOrLower_NotCEO(): Raised if a non-CEO tries to withdraw the CEO's commission.

HigherOrLower_UpkeepNotNeeded(): Raised when upkeep conditions are not met.

