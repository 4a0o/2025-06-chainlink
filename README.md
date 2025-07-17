# Chainlink Rewards audit PoC code

- Report Title: Claim contract relies on Factory admin to schedule withdrawals — funds can be permanently locked if admin key is lost
```bash
forge test --match-test FundsPermanentlyLockedOnAdminLoss
```

- Report Title: Unbounded ClaimParams enables delegated DoS against claim executors via authorized delegation
```bash
forge test --match-test UnboundedClaimParamsCausesExecutorDoS
```

- Report Title: Removing a project and redeploying a new Claim causes original Claim to lose withdraw authorization
```bash
forge test --match-test ReDeployClaimBreaksOriginalClaimWithdraw
```

- Report Title: Emergency Pause Withdrawal Bypass Breaks Project Accounting, Leading to Permanent DoS
```bash
forge test --match-test EmergencyPauseBypassesWithdrawalLimitAndBreaksAccounting
```

- Report Title: Accounting Inconsistency in Refund Logic Allows Projects to Drain Funds Prematurely
```bash
forge test --match-test RefundAccountingBrokenByPostRefundClaims
```

