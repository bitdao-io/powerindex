// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../interfaces/WrappedPiErc20Interface.sol";
import "../interfaces/aave/IStakedAave.sol";
import "./PowerIndexBasicRouter.sol";

contract AavePowerIndexRouter is PowerIndexBasicRouter {
  bytes4 public constant COOLDOWN_SIG = bytes4(keccak256(bytes("cooldown()")));
  bytes4 public constant STAKE_SIG = bytes4(keccak256(bytes("stake(address,uint256)")));
  bytes4 public constant REDEEM_SIG = bytes4(keccak256(bytes("redeem(address,uint256)")));
  bytes4 public constant VOTE_FOR_SIG = bytes4(keccak256(bytes("voteFor(uint256)")));
  bytes4 public constant VOTE_AGAINST_SIG = bytes4(keccak256(bytes("voteAgainst(uint256)")));

  constructor(address _poolRestrictions) public PowerIndexBasicRouter(_poolRestrictions) {}

  /*** THE PROXIED METHOD EXECUTORS ***/

  function executeVoteFor(address _wrappedToken, uint256 _id) external {
    _checkVotingSenderAllowed(_wrappedToken);
    _callVoting(_wrappedToken, VOTE_FOR_SIG, abi.encode(_id));
  }

  function executeVoteAgainst(address _wrappedToken, uint256 _id) external {
    _checkVotingSenderAllowed(_wrappedToken);
    _callVoting(_wrappedToken, VOTE_AGAINST_SIG, abi.encode(_id));
  }

  /*** OWNER METHODS ***/

  function stakeWrappedToVoting(address _wrappedToken, uint256 _amount) external onlyOwner {
    _stakeWrappedToStaking(_wrappedToken, _amount);
  }

  function withdrawWrappedFromVoting(address _wrappedToken, uint256 _amount) external onlyOwner {
    _withdrawWrappedFromStaking(_wrappedToken, _amount);
  }

  /*** WRAPPED TOKEN CALLBACK ***/

  function wrapperCallback(uint256 _withdrawAmount) external override {
    address wrappedToken = msg.sender;
    address votingAddress = votingByWrapped[wrappedToken];
    address stakingAddress = stakingByWrapped[wrappedToken];

    // Ignore the tokens without a voting assigned
    if (votingAddress == address(0)) {
      return;
    }

    (ReserveStatus reserveStatus, uint256 diff, ) =
      _getReserveStatus(wrappedToken, IERC20(stakingAddress).balanceOf(wrappedToken), _withdrawAmount);

    if (reserveStatus == ReserveStatus.ABOVE) {
      CoolDownStatus coolDownStatus = getCoolDownStatus(stakingAddress);
      if (coolDownStatus == CoolDownStatus.NONE) {
        // TODO: triggerCooldown
      } else if (coolDownStatus == CoolDownStatus.PENDING) {
        _withdrawWrappedFromStaking(wrappedToken, diff);
      }

      // else do nothing
    } else if (reserveStatus == ReserveStatus.BELLOW) {
      _stakeWrappedToStaking(msg.sender, diff);
    }
  }

  enum CoolDownStatus {
    NONE,
    PENDING,
    UNSTAKE_WINDOW
  }

  function getCoolDownStatus(address _stakingAddress) internal view returns (CoolDownStatus) {
    IStakedAave staking = IStakedAave(_stakingAddress);
    uint256 stakerCoolDown = staking.stakersCooldowns(address(this));
    uint256 coolDownSeconds = staking.COOLDOWN_SECONDS();
    uint256 unstakeWindow = staking.UNSTAKE_WINDOW();
    uint256 current = block.timestamp;

    if (stakerCoolDown == 0) {
     return CoolDownStatus.NONE;
    }

    uint256 coolDownFinishesAt = stakerCoolDown.add(coolDownSeconds);

    if (current <= coolDownFinishesAt) {
      return CoolDownStatus.PENDING;
    }

    uint256 unstakeFinishesAt = coolDownFinishesAt.add(unstakeWindow);

    // current > coolDownFinishesAt && ...
    if (current < unstakeWindow) {
      return (CoolDownStatus.UNSTAKE_WINDOW);
    }

    return CoolDownStatus.NONE;
  }

  /*** INTERNALS ***/

  function _triggerCoolDown(address _wrappedToken) internal {
    _callStaking(_wrappedToken, COOLDOWN_SIG, "");
  }

  function _stakeWrappedToStaking(address _wrappedToken, uint256 _amount) internal {
    require(_amount > 0, "CANT_STAKE_0");
    _approveWrappedTokenToStaking(_wrappedToken, _amount);
    _callStaking(_wrappedToken, STAKE_SIG, abi.encode(_amount));
  }

  function _withdrawWrappedFromStaking(address _wrappedToken, uint256 _amount) internal {
    require(_amount > 0, "CANT_WITHDRAW_0");
    _callStaking(_wrappedToken, REDEEM_SIG, abi.encode(_amount));
  }
}
