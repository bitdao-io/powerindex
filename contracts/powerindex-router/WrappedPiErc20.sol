// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/PowerIndexNaiveRouterInterface.sol";
import "../interfaces/PowerIndexBasicRouterInterface.sol";
import "../interfaces/WrappedPiErc20Interface.sol";

contract WrappedPiErc20 is ERC20, WrappedPiErc20Interface {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  IERC20 public immutable underlying;
  address public router;

  event Deposit(address indexed account, uint256 undelyingDeposited, uint256 piMinted);
  event Withdraw(address indexed account, uint256 underlyingWithdrawn, uint256 piBurned);
  event Approve(address indexed to, uint256 amount);
  event ChangeRouter(address indexed newRouter);
  event CallExternal(address indexed destination, bytes4 indexed inputSig, bytes inputData, bytes outputData);

  modifier onlyRouter() {
    require(router == msg.sender, "ONLY_ROUTER");
    _;
  }

  constructor(
    address _token,
    address _router,
    string memory _name,
    string memory _symbol
  ) public ERC20(_name, _symbol) {
    underlying = IERC20(_token);
    router = _router;
  }

  function pokeRouter() external {
    PowerIndexNaiveRouterInterface(router).wrapperCallback(0);
  }

  /**
   * @notice Deposits underlying token to the wrapper
   * @param _depositAmount The amount to deposit in underlying tokens
   */
  function deposit(uint256 _depositAmount) external override {
    require(_depositAmount > 0, "ZERO_DEPOSIT");

    uint256 mintAmount =
      PowerIndexBasicRouterInterface(router).getPiEquivalentFroUnderlying(
        _depositAmount,
        underlying,
        underlying.balanceOf(address(this)),
        IERC20(address(this)).totalSupply()
      );
    require(mintAmount > 0, "ZERO_PI_FOR_MINT");

    underlying.safeTransferFrom(_msgSender(), address(this), _depositAmount);
    _mint(_msgSender(), mintAmount);

    emit Deposit(_msgSender(), _depositAmount, mintAmount);

    PowerIndexNaiveRouterInterface(router).wrapperCallback(0);
  }

  /**
   * @notice Withdraws underlying token from the wrapper
   * @param _withdrawAmount The amount to withdraw in underlying tokens
   */
  function withdraw(uint256 _withdrawAmount) external override {
    require(_withdrawAmount > 0, "ZERO_WITHDRAWAL");

    PowerIndexNaiveRouterInterface(router).wrapperCallback(_withdrawAmount);

    uint256 burnAmount =
      PowerIndexBasicRouterInterface(router).getPiEquivalentFroUnderlying(
        _withdrawAmount,
        underlying,
        underlying.balanceOf(address(this)),
        IERC20(this).totalSupply()
      );
    require(burnAmount > 0, "ZERO_PI_FOR_BURN");

    ERC20(address(this)).transferFrom(_msgSender(), address(this), burnAmount);
    _burn(address(this), burnAmount);
    underlying.safeTransfer(_msgSender(), _withdrawAmount);

    emit Withdraw(_msgSender(), _withdrawAmount, burnAmount);
  }

  function changeRouter(address _newRouter) external override onlyRouter {
    router = _newRouter;
    emit ChangeRouter(router);
  }

  function approveUnderlying(address _to, uint256 _amount) external override onlyRouter {
    underlying.approve(_to, _amount);
    emit Approve(_to, _amount);
  }

  function callExternal(
    address _destination,
    bytes4 _signature,
    bytes calldata _args,
    uint256 _value
  ) external override onlyRouter {
    (bool success, bytes memory data) = _destination.call{ value: _value }(abi.encodePacked(_signature, _args));

    if (!success) {
      assembly {
        let output := mload(0x40)
        let size := returndatasize()
        switch size
          case 0 {
            // If there is no revert reason string, revert with the default `REVERTED_WITH_NO_REASON_STRING`
            mstore(output, 0x08c379a000000000000000000000000000000000000000000000000000000000) // error identifier
            mstore(add(output, 0x04), 0x0000000000000000000000000000000000000000000000000000000000000020) // starting offset
            mstore(add(output, 0x24), 0x000000000000000000000000000000000000000000000000000000000000001e) // reason length
            mstore(add(output, 0x44), 0x52455645525445445f574954485f4e4f5f524541534f4e5f535452494e470000) // reason
            revert(output, 100) // 100 = 4 + 3 * 32 (error identifier + 3 words for the ABI encoded error)
          }
          default {
            // If there is a revert reason string hijacked, revert with it
            mstore(0x40, add(output, size))
            returndatacopy(output, 0, size)
            mstore(0x40, add(output, size))
            revert(output, size)
          }
      }
    }

    emit CallExternal(_destination, _signature, _args, data);
  }

  function getUnderlyingBalance() external view override returns (uint256) {
    return underlying.balanceOf(address(this));
  }
}
