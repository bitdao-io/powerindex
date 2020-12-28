// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/WrappedPiErc20Interface.sol";
import "../interfaces/PowerIndexNaiveRouterInterface.sol";

contract PowerIndexNaiveRouter is PowerIndexNaiveRouterInterface, Ownable {
  using SafeMath for uint256;

  function migrateToNewRouter(address _piToken, address _newRouter) external override onlyOwner {
    WrappedPiErc20Interface(_piToken).changeRouter(_newRouter);
  }

  function piTokenCallback(uint256 _withdrawAmount) external virtual override {
    // DO NOTHING
  }
}
