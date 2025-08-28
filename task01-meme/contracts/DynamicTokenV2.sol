// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract DynamicTokenV2 is  Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    // 1. 税收相关的参数
    // 1.1 动态税率
    struct TaxTier {
        uint256 taxRate;
        uint256 minAmount;
    }
    TaxTier[] internal taxTiers; 
    // =  [
    //     // 初始化税率5%
    //     TaxTier(5, 0),
    //     // 大于等于100数量的交易，税率为8%。。。。总体思路是交易数量越多税率越高，避免大额交易
    //     TaxTier(8, 100)
    // ];
    // 1.2 税收集地址
    address public taxCollector;

    // 2. 流动性池
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    // 3. 交易限制
    // 3.1 单次交易数量限制（1000个）
    uint256 public maxTxAmount;
    // 3.2 每日交易次数限制
    mapping(address => uint256) public dailyTransactionCount;
    mapping(address => uint256) public lastTransactionDay;
    uint256 public maxTransactionsPerDay;
    
    modifier withinDailyLimit(uint256 amount) {
        // 单次交易数量限制
        require(amount <= maxTxAmount, "Transaction amount exceeds daily limit");

        // 每天交易次数限制
        uint256 currentDay = block.timestamp / 1 days;
        // 如果是新的一天，重置计数器
        if (lastTransactionDay[msg.sender] != currentDay) {
            dailyTransactionCount[msg.sender] = 0;
            lastTransactionDay[msg.sender] = currentDay;
        }
        // 检查是否超过限制
        require(
            dailyTransactionCount[msg.sender] < maxTransactionsPerDay,
            "Daily transaction limit exceeded"
        );
        
        _;
        
        // 增加交易计数
        dailyTransactionCount[msg.sender]++;
    }

    // 4. 自动升级所需要的相关改造 
    function initialize(
        address _taxCollector,
        address _routerAddress
    ) public initializer {
        require(_taxCollector != address(0), "_taxCollector is nil");
        __ERC20_init("MyToken", "MySymbol");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        taxCollector = _taxCollector;
        
        taxTiers.push(TaxTier(5, 0));
        taxTiers.push(TaxTier(8, 100));
        // 升级合约中的状态变量必须在initial中初始化，直接初始化会导致合约自动创建构造函数进行初始化，
        // 但是在升级过程中不会调用构造函数，因此需要使用initial进行初始化，
        // 且带有构造函数的合约与不带构造函数的合约在存储布局上可能不兼容
        maxTxAmount = 1000 * 10 ** decimals();
        maxTransactionsPerDay = 5;

        if (_routerAddress != address(0)) {
            // 初始化 Uniswap 路由
            IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_routerAddress);
            uniswapV2Router = _uniswapV2Router;
            
            // 创建代币交易对
            uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        }
    }
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {
        
    }

    // **************** 交易方法 ****************
    function transfer(        
        address sender,
        address recipient,
        uint256 amount
    ) public withinDailyLimit(amount) { 
        // 获取费率
        uint256 fee = _getFee(amount);
        uint256 taxAmount = amount * fee / 100;
        uint256 realTransferAmount = amount - taxAmount;
        super._transfer(sender, recipient, realTransferAmount);
        if (taxAmount > 0) {
            super._transfer(sender, taxCollector, taxAmount);
        }
    }

    function _getFee(uint256 amount) internal view returns (uint256) {
        // 获取费率
        if (taxTiers.length == 0) {
            return 5;
        }

        for (uint256 i = 0; i < taxTiers.length; i++) {
            TaxTier memory taxTier = taxTiers[i];
            if (amount >= taxTier.minAmount) {
                return taxTier.taxRate;
            }
        }

        return 5;
    }

    // **************** 流动性相关操作方法 ****************
    // 添加流动性
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external onlyOwner {
        // 批准路由器使用代币
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        // 添加流动性
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // 滑点保护设置为最小 (仅演示用)
            0, // 滑点保护设置为最小 (仅演示用)
            owner(),
            block.timestamp
        );
    }
    // 移除流动性
    function removeLiquidity(uint256 liquidity) external onlyOwner {
        // 批准路由器使用流动性代币
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), liquidity);
        
        // 移除流动性
        uniswapV2Router.removeLiquidityETH(
            address(this),
            liquidity,
            0, // 滑点保护设置为最小 (仅演示用)
            0, // 滑点保护设置为最小 (仅演示用)
            owner(),
            block.timestamp
        );
    }

}