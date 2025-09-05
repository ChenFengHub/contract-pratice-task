## cast操作指南

### Pure函数调用（只读，不消耗gas）
// 调用 add 函数 (pure)
cast call $CONTRACT_ADDR "add(uint256,uint256)" 10 20 --rpc-url $RPC_URL
// 调用 optimizedAdd 函数 (pure)
cast call $CONTRACT_ADDR "optimizedAdd(uint256,uint256)" 30 40 --rpc-url $RPC_URL

### View函数调用（只读，不消耗gas）
* 合约
contract MathOps {
    uint256 public totalOperations;
    
    function getTotalOperations() public view returns (uint256) {
        return totalOperations;
    }
}
* 调用示例
cast call $CONTRACT_ADDR "getTotalOperations()" --rpc-url $RPC_URL

### 状态修改函数调用（消耗gas）
* 合约
contract MathOps {
    uint256 public counter;
    
    function incrementCounter() public {
        counter++;
    }
}
* 示例
// 调用 incrementCounter 函数，方法从call改为send，而且需要钱包账户私钥$PRIVATE_KEY
cast send $CONTRACT_ADDR "incrementCounter()" \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

### Payable函数调用（发送ETH）
* 合约
contract MathOps {
    mapping(address => uint256) public balances;
    
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }
}
* 示例
// 发送 0.1 ETH 到 deposit 函数
cast send $CONTRACT_ADDR "deposit()" \
--value 0.1ether \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

### 带参数的函数调用
//调用带参数的 pure 函数
cast call $CONTRACT_ADDR "add(uint256,uint256)" 100 200 --rpc-url $RPC_URL
//调用带参数的 payable 函数
cast send $CONTRACT_ADDR "transfer(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 1000000000000000000 \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

### 获取交易信息
// 获取交易收据
cast receipt <TX_HASH> --rpc-url $RPC_URL
// 获取交易详情
cast tx <TX_HASH> --rpc-url $RPC_URL
// 获取合约存储
cast storage $CONTRACT_ADDR 0 --rpc-url $RPC_URL

### 调用并解析返回值
// 调用并解析返回的元组
cast call $CONTRACT_ADDR "getUserData(address)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
--rpc-url $RPC_URL | cast --abi-decode "getUserData(address)(uint256,uint256)"

### 批量调用示例
# 批量调用多个函数
cast send $CONTRACT_ADDR \
"incrementCounter()" \
"deposit()" --value 0.05ether \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

### 高级用法：估算Gas和设置gas价格
// 估算 Gas 消耗
cast estimate $CONTRACT_ADDR "incrementCounter()" \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

// 设置自定义 Gas 价格
cast send $CONTRACT_ADDR "incrementCounter()" \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL \
--gas-price 1000000000 \ # 1 Gwei
--gas-limit 100000

### 与ABI交互
// 生成 ABI
forge inspect MathOps abi > MathOps.abi
// 使用 ABI 调用函数
cast call --abi MathOps.abi $CONTRACT_ADDR "add(uint256,uint256)" 5 7 --rpc-url $RPC_URL

### 完整示例
// 1. 部署合约
forge create src/MathOps.sol:MathOps \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY

// 2. 调用 pure 函数
cast call $CONTRACT_ADDR "add(uint256,uint256)" 10 20 --rpc-url $RPC_URL

// 3. 调用 view 函数
cast call $CONTRACT_ADDR "getTotalOperations()" --rpc-url $RPC_URL

// 4. 修改状态
cast send $CONTRACT_ADDR "incrementCounter()" \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

// 5. 发送 ETH
cast send $CONTRACT_ADDR "deposit()" \
--value 0.1ether \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL

// 6. 验证状态变化
cast call $CONTRACT_ADDR "getTotalOperations()" --rpc-url $RPC_URL
cast call $CONTRACT_ADDR "balances(address)" $YOUR_ADDRESS --rpc-url $RPC_URL