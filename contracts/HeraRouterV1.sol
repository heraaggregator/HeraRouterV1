pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IERC20.sol";

contract HeraRouterV1 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct SwapDetail {
        IERC20 token0;
        IERC20 token1;
        address router;
        address[] path;
        uint256 amountIn;
        uint256 amountOutMin;
    }
    uint256 public feeRate = 300; // %1 = 1000
    address public feeAddress;
    mapping(address => bytes4) public routerSelector;
    mapping(address => bool) public suppertedRouters;

    event Swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _feeAddress) public {
        feeAddress = _feeAddress;
    }

    function setRouterSelector(bytes4 selector, address router)
        public
        onlyOwner
    {
        routerSelector[router] = selector;
    }

    function setAvailableRouter(bool available, address router)
        public
        onlyOwner
    {
        suppertedRouters[router] = available;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeeRate(uint256 _feeRate) public onlyOwner {
        feeRate = _feeRate;
    }

    function swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        SwapDetail[] memory details
    ) public nonReentrant {
        require(
            tokenIn.transferFrom(msg.sender, address(this), amountIn),
            "TRANSFERFROM_FAILED"
        );
        _swap(tokenIn, tokenOut, amountIn, amountOutMin, details);
    }

    function swapMETIS(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        SwapDetail[] memory details
    ) public payable nonReentrant {
        require(msg.value >= amountIn, "INVALID_VALUE");
        _swap(tokenIn, tokenOut, amountIn, amountOutMin, details);
    }

    function _swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        SwapDetail[] memory details
    ) private {
        uint256 feeAmount = amountIn.mul(feeRate).div(1e5);
        if (feeAmount > 0) {
            tokenIn.transfer(feeAddress, feeAmount);
        }
        for (uint256 i = 0; i < details.length; i++) {
            SwapDetail memory detail = details[i];
            require(suppertedRouters[detail.router], "UNSUPPORTED_ROUTER");
            detail.token0.approve(detail.router, detail.amountIn);
            bytes memory callData = abi.encodeWithSelector(
                routerSelector[detail.router],
                detail.amountIn,
                detail.amountOutMin,
                detail.path,
                address(this),
                block.timestamp
            );
            (bool success, ) = address(detail.router).call(callData);
            require(success, "SWAP_FAILED");
        }
        uint256 amountOut = tokenOut.balanceOf(address(this));
        require(amountOut >= amountOutMin, "INVALID_OUT");
        tokenOut.transfer(msg.sender, amountOut);
        emit Swap(address(tokenIn), address(tokenOut), amountIn, amountOut);
    }
}
