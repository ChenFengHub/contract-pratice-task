// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MetaNodeStake is Initializable, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable {

    using Math for uint256;
    using SafeERC20 for IERC20;

    // *********************** 常量 ***********************
    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    
    // ********************** 结构体 **********************
    struct Pool {
        address stTokenAddress; // 质押代币的地址。
        uint256 poolWeight;     // 质押池的权重，影响奖励分配。
        uint256 lastRewardBlock;        // 最后一次计算奖励的区块号。
        uint256 accMetaNodePerST;       // 每个质押代币累积的 RCC(​​Reward Credit Coin;奖励积分币) 数量。这个值是乘以10^18的，提取时需要除以10^18。
        uint256 stTokenAmount;          // 池中的总质押代币量。
        uint256 minDepositAmount;       // 最小质押金额。
        uint256 unstakeLockedBlocks;    // 解除质押的锁定区块数。
    }

    struct User {
        uint256 stAmount;           // 用户质押的代币数量。
        uint256 finishedMetaNode;   // 已分配的 MetaNode数量。
        uint256 pendingMetaNode;    // 待领取的 MetaNode 数量。
        UnStakeRequest[] requests;  // 解质押请求列表，每个请求包含解质押数量和解锁区块。
    }

    struct UnStakeRequest {
        uint256 amount;      // 解质押数量。
        uint256 unlockBlock; // 解锁区块号。
    }

    // ************************* 事件 *************************
    event AddPool(
        uint256 poolId,
        address indexed user,
        address indexed stTokenAddress, // 质押代币的地址。
        uint256 poolWeight,             // 质押池的权重，影响奖励分配。
        uint256 minDepositAmount,       // 最小质押金额。
        uint256 unstakeLockedBlocks     // 解除质押的锁定区块数。
    );
    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);
    event UpdatePool2(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 unstakeLockedBlocks);
    event SetMetaNode(IERC20 indexed MetaNode);
    event Stake(address indexed user, uint256 indexed poolId, uint256 amount);
    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);

    // ************************* 状态变量 *************************
    Pool[] internal pools;
    // pool id => user address => user info
    mapping (uint256 => mapping (address => User)) public users;
    uint256 internal totalPoolWeight;
    // 每个区块奖励的数量（固定值）
    uint256 public MetaNodePerBlock;
    bool internal stakePaused;
    bool internal claimPaused;
    // MetaNode token
    IERC20 public MetaNode;

    // ************************* 修饰符 ***********************
    modifier checkPid(uint256 _pid) { 
        require(_pid < pools.length, "Pool does not exist");
        _;
    }
    modifier whenStakeNotPaused() { 
        require(!stakePaused, "Stake is paused");
        _;
    }
    modifier whenClaimNotPaused() { 
        require(!claimPaused, "Claim is paused");
        _;
    }


    // ************************* 2.1 质押功能  *************************
    /**
     * @notice 质押代币
     * @param _pid The pool id
     * @param _amount The amount of MetaNode token to stake
     */
    function stakeToken(uint256 _pid, uint256 _amount) 
        public 
        checkPid(_pid) whenStakeNotPaused 
    {
        require(_amount > 0, "Amount must be greater than 0");
        // User storage user_ = users[_pid][msg.sender];
        Pool storage pool_ = pools[_pid];
        require(_amount > pool_.minDepositAmount, "Amount must be greater than minDepositAmount");
        require(pool_.stTokenAddress != address(0), "stTokenAddress is not set");

        // token池中币的数据就是直接保存在当前合约中，后面提取就直接从当前合约中提取
        IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);

        // 更新当前池的质押信息和用户质押信息
        _stake(_pid, _amount);
    }

    function stakeETH(uint256 _pid) 
        external payable 
        checkPid(_pid) whenStakeNotPaused 
    {
        require(msg.value > 0, "Must stake more than 0");
        Pool storage pool_ = pools[_pid];
        require(pool_.stTokenAddress == address(0), "stTokenAddress must be zero address");

        // ether自动保存到当前合约中

        // 更新当前池的质押信息和用户质押信息
        _stake(_pid, msg.value);
    }

    receive() external payable {}

    function _stake(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pools[_pid];
        User storage user_ = users[_pid][msg.sender];

        updatePool(_pid);

        if (user_.stAmount > 0) {
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            // pool_.accMetaNodePerST值本身为了精度，所以是乘以1e18的，所以要除以1e18
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");

            if(pendingMetaNode_ > 0) {
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        if(_amount > 0) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }

        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");

        user_.finishedMetaNode = finishedMetaNode;

        emit Stake(msg.sender, _pid, _amount);
    }

    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pools[_pid];

        if (block.number <= pool_.lastRewardBlock) {
            // 已经更新过
            return;
        }

        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");

        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");

        uint256 stSupply = pool_.stTokenAmount;
        // 这里累计的pool_.accMetaNodePerST是自定义代币的奖励而不是具体池中质押的代币或者ether，既然不是ether基本不用考虑越界的问题
        if (stSupply > 0) {
            // 这里乘以 1 ether 是为了避免精度丢失
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");

            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            // 这里累加的值都是乘以 1 ether后的，后续提取的时候需要除以 1 ether
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }

        // 块被人领取过，则其他们就不会再领取，所以一个用户不管只用触发奖励领取即使stSupply=0，其他人也无法再领取了
        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    // ************************* 2.2 解除质押功能  *************************
    function unStake(uint256 _pid, uint256 _amount) 
        external
        checkPid(_pid) whenStakeNotPaused 
    {
        require(_amount > 0, "amount must be greater than zero");

        Pool storage pool_ = pools[_pid];

        // 获取用户质押信息
        User storage user_ = users[_pid][msg.sender];
        require(user_.stAmount >= _amount, "Amount must be less than or equal to staked amount");

        // 重新更新累计的MetaNode奖励
        updatePool(_pid);

        // 获取当前池的质押代币合约
        user_.stAmount = user_.stAmount - _amount;
        user_.requests.push(UnStakeRequest(_amount, block.number + pool_.unstakeLockedBlocks));

        // 更新池信息
        pool_.stTokenAmount = pool_.stTokenAmount - _amount;
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / 1 ether;

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    // ************************* 2.3 领取奖励功能+提取功能（将接触质押的代币或者ether取回，不涉及pendingMetaNode奖励提取，这个要等claimReward中领取） *************************
    function withdraw(uint256 _pid) external checkPid(_pid) whenStakeNotPaused { 
        Pool storage pool_ = pools[_pid];
        User storage user_ = users[_pid][msg.sender];
        uint256 totalToken_;
        uint256 popNum_ = 0;
        for (uint256 i = 0; i < user_.requests.length; i++) {
            UnStakeRequest memory request = user_.requests[i];
            if (block.number >= request.unlockBlock) {
                 totalToken_ += request.amount;
                 popNum_++;
            }
        }
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }
        if(totalToken_ > 0) {
            if (pool_.stTokenAddress == address(0)) {
                _safeETHTransfer(msg.sender, totalToken_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, totalToken_);
            }
        }

        emit Withdraw(msg.sender, _pid, totalToken_);
    }
    
    function claimReward(uint256 _pid) external checkPid(_pid) whenClaimNotPaused { 
        Pool storage pool_ = pools[_pid];
        User storage user_ = users[_pid][msg.sender];
        
        // 重新统计当前用户accMetaNodePerST累计值
        updatePool(_pid);

        // 正常user_.stAmount.mul(pool_.accMetaNodePerST).div(1 ether) = user_.finishedMetaNode，这里多加这个可能防止user_.stAmount数量变更，那奖励会变多（正常不可能出现吧？）
        uint256 pengdingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / 1 ether + user_.pendingMetaNode - user_.finishedMetaNode;
        if(pengdingMetaNode_ > 0) {
            _safeMetaNodeTransfer(msg.sender, pengdingMetaNode_);
        }
        user_.pendingMetaNode = user_.stAmount * pool_.accMetaNodePerST / 1 ether;

        emit Claim(msg.sender, _pid, pengdingMetaNode_);
    }
    /**
     * @notice 获取有效的区块奖励的累计值
     *
     * @param _from    From block number (included)
     * @param _to      To block number (exluded)
     * getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
     */
    function getMultiplier(uint256 _from, uint256 _to) internal view returns(uint256 multiplier) {
        require(_from <= _to, "invalid block");
        // 这里没有起始区块限制（正常可以添加）
        bool success;
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);
        require(success, "multiplier overflow");
    }
    /**
     * @notice Safe MetaNode transfer function, just in case if rounding error causes pool to not have enough MetaNodes
     *
     * @param _to        Address to get transferred MetaNodes
     * @param _amount    Amount of MetaNode to be transferred
     */
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));

        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }

    /**
     * @notice Safe ETH transfer function
     *
     * @param _to        Address to get transferred ETH
     * @param _amount    Amount of ETH to be transferred
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        // ​​.transfer()和 .send()​​：这两个函数在转账时会​​严格地将 Gas 限制在 2300 units​​。
        // 这个 Gas 量只够接收方合约的 receive()或 fallback()函数记录一个日志（emit an event），
        //几乎做不了任何其他操作。而call没有这些限制，让接收者可以做更多操作
        (bool success, bytes memory data) = address(_to).call{
            value: _amount
        }("");

        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }

    // ************************* 2.4添加和更新质押池（质押池不可删除）--管理后台-管理员可操作 *************************
    function addPool(address _stTokenAddress, 
                    uint256 _poolWeight,                             
                    uint256 _minDepositAmount,       
                    uint256 _unstakeLockedBlocks    
    ) public onlyRole(ADMIN_ROLE) returns (uint256 poolId) { 
        // 第一次添加的池必须为ether池，地址为：0x0
        if (pools.length == 0) { 
            require(_stTokenAddress == address(0), "The first pool must be ether pool.");
        } else {
            require(_stTokenAddress != address(0), "The stToken address must not be zero.");
        }

        // 更新总的权重
        totalPoolWeight += _poolWeight;

        pools.push(Pool({
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: block.number,
                accMetaNodePerST: 0,
                stTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
        }));

        poolId = pools.length - 1;
        emit AddPool(poolId, msg.sender, _stTokenAddress, _poolWeight, _minDepositAmount, _unstakeLockedBlocks);
    }
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        Pool storage pool_ = pools[_pid];
        pool_.minDepositAmount = _minDepositAmount;
        pool_.unstakeLockedBlocks = _unstakeLockedBlocks;
        emit UpdatePool2(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    // ************************* 2.5 合约升级和暂停 *************************
    // 透明代理模式
    function initialize(
        uint256 _metaNodePerBlock,
        address _MetaNode
    ) public initializer {
        require(_metaNodePerBlock > 0, "MetaNodePerBlock must be greater than 0");
        MetaNodePerBlock = _metaNodePerBlock;

        __ERC20_init("MetaNodeStake", "MNSymbol");
        __AccessControl_init();
        __Pausable_init();
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);

        setMetaNode(_MetaNode);
    }

    function isPoolExist(uint256 _pid) public view returns (bool) {
        return _pid < pools.length;
    }
    
    /**
     * @notice Set MetaNode token address. Can only be called by admin
     */
    function setMetaNode(address _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = IERC20(_MetaNode);

        emit SetMetaNode(MetaNode);
    }

    /**
     * @notice 质押的暂停
     */
    function pauseStake() public onlyRole(ADMIN_ROLE) {
        stakePaused = true;
    }
    /**
     * @notice 质押的恢复
     */
    function resumeStake() public onlyRole(ADMIN_ROLE) {
        stakePaused = false;
    }
    /**
     * @notice 体现/领取的暂停
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        claimPaused = true;
    }
    /**
     * @notice 提现/领取的恢复
     */
    function resumeWithdraw() public onlyRole(ADMIN_ROLE) {
        claimPaused = false;
    }

    
    
}