## 理论知识回顾
理论知识回顾：请简要阐述 Foundry 框架作为智能合约测试 / 部署 / 调试全流程工具链的主要组成部分及其功能。

### ​全流程能力：​​
* ​​测试​​：通过 Forge 执行全面测试套件
* 部署​​：使用 Forge 脚本部署到任意 EVM 网络
* 调试​​：利用交易追踪和 console.log 调试
* 优化​​：基于 Gas 报告进行合约优化

### Foundry作为测试框架
#### 组件为：Forge
#### 功能：
• 支持单元/模糊/差分测试
• Solidity 编写测试
• 内置 Gas 报告
• 覆盖率分析
• 作弊码系统

### Foundry 合约交互CLI工具
#### 组件为：Cast
#### 功能：
• 发送交易
• 调用视图函数
• 解码 calldata
• 查询链上数据

### Foundry 本地开发节点
#### 组件为：Anvil
#### 功能为：
• 分叉主网
• 即时挖矿
• 账户预充值
• 区块时间控制

### Foundry 的Solidity REPL
#### 组件为：Chisel
#### 功能为：
• 快速代码实验
• 即时执行验证


## 实践操作
### 智能合约代码（src目录下创建MathOps.sol）
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MathOps {
    // 原始实现
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        require(a >= b, "Underflow error");
        return a - b;
    }

    // 优化版本
    function optimizedAdd(uint256 a, uint256 b) public pure returns (uint256) {
        // 策略1：使用unchecked减少溢出检查，出现溢出则直接返回截断后的错误结果(在 Solidity 0.8.0 及以上版本中，​​所有算术运算默认会自动检查溢出​​)
        unchecked { return a + b; }
    }

    function optimizedSub(uint256 a, uint256 b) public pure returns (uint256) {
        // 策略2：内联require检查
        if (a < b) revert("Underflow error");   // if + revert 对比require少量节省gas
        unchecked { return a - b; }             // 不进行溢出检查大量节省gas
    }
}


### 测试代码(test目录下添加MathOpsTest.sol) 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MathOps.sol";

contract MathOpsTest is Test {
    MathOps math;
    
    function setUp() public {
        math = new MathOps();
    }

    // 基础运算测试
    function testAdd() public {
        assertEq(math.add(5, 3), 8);
    }

    function testSub() public {
        assertEq(math.sub(10, 4), 6);
    }

    function testSubRevert() public {
        vm.expectRevert("Underflow error");
        math.sub(3, 5);
    }

    // 优化版本测试
    function testOptimizedAdd() public {
        assertEq(math.optimizedAdd(5, 3), 8);
    }

    function testOptimizedSub() public {
        assertEq(math.optimizedSub(10, 4), 6);
    }

    function testOptimizedSubRevert() public {
        vm.expectRevert();
        math.optimizedSub(3, 5);
    }

    // 模糊测试
    function testAddFuzz(uint256 a, uint256 b) public {
        // 防止算术溢出(执行模糊测试，可能出现溢出，这样测试会报错终端测试)
        unchecked {
            uint256 expected = a + b;
            // 仅当不溢出时进行断言
            if (a <= type(uint256).max - b) {
                assertEq(math.add(a, b), expected);
            }
        }
    }

    function testOptimizedAddFuzz(uint256 a, uint256 b) public {
        // 优化版本允许溢出（自动取模）
        unchecked {
            uint256 expected = a + b;
            assertEq(math.optimizedAdd(a, b), expected);
        }
    }
}

### 添加前置依赖，否则报错："forge-std/Test.sol" 这些依赖类找不到
（原有的项目是通过 forge init task03-foundry）
forge init --force
forge install foundry-rs/forge-std

### 覆盖率报告（90%+ 覆盖率验证）
* 生成测试报告指令(本身也会执行测试类似forge test效果)：forge coverage --report summary
    * --report 参数是指定输出格式，默认就是 summary，所以如果是摘要形式可以不用 --report summary参数
    * --reprot lcov：输出cov格式报告，可用于其他工具生成HTML之类格式报告
    * --report json: 输出json格式报告
* 覆盖率结果
Analysing contracts...
Running tests...

Ran 8 tests for test/MathOpsTest.sol:MathOpsTest
[PASS] testAdd() (gas: 6922)
[PASS] testAddFuzz(uint256,uint256) (runs: 258, μ: 6735, ~: 7168)
[PASS] testOptimizedAdd() (gas: 6742)
[PASS] testOptimizedAddFuzz(uint256,uint256) (runs: 258, μ: 6849, ~: 6849)
[PASS] testOptimizedSub() (gas: 6792)
[PASS] testOptimizedSubRevert() (gas: 9654)
[PASS] testSub() (gas: 6947)
[PASS] testSubRevert() (gas: 9897)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 5.55ms (13.86ms CPU time)

Ran 1 test suite in 18.81ms (5.55ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)

╭-----------------+-----------------+-----------------+---------------+---------------╮
| File            | % Lines         | % Statements    | % Branches    | % Funcs       |
+=====================================================================================+
| src/MathOps.sol | 100.00% (10/10) | 100.00% (11/11) | 100.00% (3/3) | 100.00% (4/4) |
|-----------------+-----------------+-----------------+---------------+---------------|
| Total           | 100.00% (10/10) | 100.00% (11/11) | 100.00% (3/3) | 100.00% (4/4) |
╰-----------------+-----------------+-----------------+---------------+---------------╯

### gas消耗数据记录
* 指令：forge test --gas-report
* 优化前的gas消耗：
    * add avg:948
    * sub avg:948
* 优化后的gas消耗：
    * optimizedAdd avg: 747 节省：201，节省率：21.2%
    * optimizedSub avg: 881 节省： 67，节省率：7.1%
Ran 8 tests for test/MathOpsTest.sol:MathOpsTest
[PASS] testAdd() (gas: 6922)
[PASS] testAddFuzz(uint256,uint256) (runs: 258, μ: 6694, ~: 7168)
[PASS] testOptimizedAdd() (gas: 6742)
[PASS] testOptimizedAddFuzz(uint256,uint256) (runs: 258, μ: 6849, ~: 6849)
[PASS] testOptimizedSub() (gas: 6792)
[PASS] testOptimizedSubRevert() (gas: 9654)
[PASS] testSub() (gas: 6947)
[PASS] testSubRevert() (gas: 9897)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 4.11ms (7.71ms CPU time)

╭----------------------------------+-----------------+-----+--------+-----+---------╮
| src/MathOps.sol:MathOps Contract |                 |     |        |     |         |
+===================================================================================+
| Deployment Cost                  | Deployment Size |     |        |     |         |
|----------------------------------+-----------------+-----+--------+-----+---------|
| 257056                           | 976             |     |        |     |         |
|----------------------------------+-----------------+-----+--------+-----+---------|
|                                  |                 |     |        |     |         |
|----------------------------------+-----------------+-----+--------+-----+---------|
| Function Name                    | Min             | Avg | Median | Max | # Calls |
|----------------------------------+-----------------+-----+--------+-----+---------|
| add                              | 948             | 948 | 948    | 948 | 238     |
|----------------------------------+-----------------+-----+--------+-----+---------|
| optimizedAdd                     | 747             | 747 | 747    | 747 | 257     |
|----------------------------------+-----------------+-----+--------+-----+---------|
| optimizedSub                     | 839             | 881 | 881    | 923 | 2       |
|----------------------------------+-----------------+-----+--------+-----+---------|
| sub                              | 901             | 948 | 948    | 996 | 2       |
╰----------------------------------+-----------------+-----+--------+-----+---------╯


Ran 1 test suite in 20.67ms (4.11ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)

### 调试
所谓调试即执行特定的方法，且特定方法满足自己的要求
* 指定特定方法（方法可以在在src下，也可以在test下，也可以在script下）
forge test -vvv --match-test testOptimizedSubRevert
* 也可以在test下创建一个调试的合约，调用多个方法，验证方法没有语法报错且符合自己的预期【如下调试代码将常用vm.func都整合了】
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MathOps.sol";

contract DebugMathOps is Test {
    MathOps math;
    address alice = address(0x123);
    address bob = address(0x456);
    
    function setUp() public {
        math = new MathOps();
        
        // 给地址添加标签，便于调试
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(this), "TestContract");
        vm.label(address(math), "MathContract");
    }

    function testDebug() public {
        // 1. 基本算术运算调试
        console.log("===== Basic Arithmetic Debugging =====");
        uint256 result = math.add(5, 3);
        console.log("Add result:", result);
        
        result = math.sub(10, 4);
        console.log("Sub result:", result);
        
        // 2. 账户操作：分配 ETH
        console.log("\n===== Account Operations =====");
        console.log("Alice balance before:", alice.balance);
        vm.deal(alice, 10 ether);
        console.log("Alice balance after:", alice.balance);
        
        // 3. 模拟调用者 (prank)
        console.log("\n===== Simulating Caller =====");
        console.log("Current sender:", msg.sender);
        
        vm.prank(alice);
        console.log("Sender after prank:", msg.sender);
        
        // 4. 区块操作：修改时间和高度
        console.log("\n===== Block Operations =====");
        console.log("Current block:", block.number, "Timestamp:", block.timestamp);
        
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 100);
        console.log("After warp/roll - Block:", block.number, "Timestamp:", block.timestamp);
        
        // 5. 预期错误处理
        console.log("\n===== Expected Error Handling =====");
        vm.expectRevert("Underflow error");
        math.sub(3, 5);
        console.log("Expected revert occurred");
        
        // 6. 状态快照和恢复
        console.log("\n===== State Snapshots =====");
        uint256 snapshot = vm.snapshot();
        console.log("Snapshot ID:", snapshot);
        
        // 修改状态
        vm.deal(bob, 5 ether);
        console.log("Bob balance after deal:", bob.balance);
        
        // 恢复状态
        vm.revertTo(snapshot);
        console.log("Bob balance after revert:", bob.balance);
        
        // 7. 模拟外部调用
        console.log("\n===== Simulating External Calls =====");
        address oracle = address(0x789);
        vm.label(oracle, "Oracle");
        
        // 设置模拟调用
        bytes memory callData = abi.encodeWithSignature("getPrice(address)", address(0));
        bytes memory returnData = abi.encode(2000);
        vm.mockCall(oracle, callData, returnData);
        
        // 测试模拟调用
        (bool success, bytes memory data) = oracle.call(callData);
        require(success, "Call failed");
        uint256 price = abi.decode(data, (uint256));
        console.log("Oracle price:", price);
        
        // 8. 预期事件 - 移除这部分，因为MathOps合约没有Deposit事件
        // console.log("\n===== Expected Events =====");
        // 为演示添加存款功能
        // vm.deal(address(this), 1 ether);
        
        // vm.expectEmit(true, true, true, true);
        // emit Deposit(address(this), 1 ether);
        
        // 假设合约有存款功能
        // math.deposit{value: 1 ether}();
        // console.log("Expected deposit event emitted");
        
        // 9. 模糊测试输入过滤
        console.log("\n===== Fuzz Test Filtering =====");
        uint256 a = 100;
        uint256 b = 200;
        vm.assume(a > 0 && b > 0);
        vm.assume(a < type(uint256).max - b);
        console.log("Filtered values: a=%s, b=%s", a, b);
        
        // 10. 环境变量操作
        console.log("\n===== Environment Variable Operations =====");
        vm.setEnv("API_KEY", "test123");
        string memory apiKey = vm.envString("API_KEY");
        console.log("API Key:", apiKey);
        
        // 11. 链 ID 操作
        console.log("\n===== Chain ID Operations =====");
        console.log("Original chain ID:", block.chainid);
        vm.chainId(137); // Polygon 链 ID
        console.log("New chain ID:", block.chainid);
        
        // 12. Nonce 操作
        console.log("\n===== Nonce Operations =====");
        console.log("Alice nonce before:", vm.getNonce(alice));
        vm.setNonce(alice, 5);
        console.log("Alice nonce after:", vm.getNonce(alice));
        
        console.log("\n===== Debugging Completed =====");
    }
}
* 指令（指定执行某个方法）：forge test -vvv --match-test testDebug
* 指令（指定执行某个合约）：forge test --match-contract DebugMathOps -vv
* 日志输出级别
    * -v:默认级别。只显示测试名称和结果（快速运行测试套件）
    * -vv:额外显示测试日志输出，比如console.log的输出（查看console.log输出）
    * -vvv:额外显示失败测试的调用跟踪（调试失败使用此）
    * -vvvv:额外显示所有测试的完整调用跟踪（深度调试复杂问题）
* 结果
Ran 1 test for test/DebugMathOps.sol:DebugMathOps
[PASS] testDebug() (gas: 74038)
Logs:
  ===== Basic Arithmetic Debugging =====
  Add result: 8
  Sub result: 6
  
===== Account Operations =====
  Alice balance before: 0
  Alice balance after: 10000000000000000000
  
===== Simulating Caller =====
  Current sender: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
  Sender after prank: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
  
===== Block Operations =====
  Current block: 1 Timestamp: 1
  After warp/roll - Block: 101 Timestamp: 86401
  
===== Expected Error Handling =====
  Expected revert occurred
  
===== State Snapshots =====
  Snapshot ID: 0
  Bob balance after deal: 5000000000000000000
  Bob balance after revert: 0
  
===== Simulating External Calls =====
  Oracle price: 2000
  
===== Fuzz Test Filtering =====
  Filtered values: a=100, b=200
  
===== Environment Variable Operations =====
  API Key: test123
  
===== Chain ID Operations =====
  Original chain ID: 31337
  New chain ID: 137
  
===== Nonce Operations =====
  Alice nonce before: 0
  Alice nonce after: 5
  
===== Debugging Completed =====

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 819.10µs (373.10µs CPU time)

Ran 1 test suite in 18.13ms (819.10µs CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 502.00µs (212.90µs CPU time)

Ran 1 test suite in 17.66ms (502.00µs CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)

### 部署到测试网络
* 配置环境变量,新建配置文件：.env
PRIVATE_KEY=3a240ce3cd5b1860f9ded009a932ecad2cd60f08088df1d23aa1d614cc225106
RPC_URL=https://hoodi.infura.io/v3/b6a39ba8bb49482fbef08826773901cc
* 部署合约，执行指令如下
# 部署到Hoodi测试网
* 格式：forge script <文件路径>:<合约名>)
* veriry和etherscan-api-key成套的，可以都不加，不加就无法在合约部署完成后，​​自动将您的合约源代码提交给区块浏览器（如Etherscan或Blockscout）进行验证​​。这个密钥证明了您有权限通过API向该浏览器提交信息。
    * ​​类比​​：这就像是您在某个论坛（区块浏览器）的“账号密码”，有了它才能发帖（提交验证）。
    * hardhat 为什么不需要这个呢？
        * Forge​​：追求的是 ​​“一体化和自动化”​​。
        它的设计理念是​​一条命令完成所有事情​​：编译、部署、验证。因此，它将验证作为部署流程的一个内置、默认可选的步骤，这就需要您预先配置好验证所需的API密钥。
        * ​​Hardhat​​：更偏向于 ​​“模块化和灵活性”​​。
        在Hardhat中，部署和验证通常是​​两个独立的步骤​​。您通常会先用 deploy脚本部署合约，然后再运行单独的 verify命令或使用 hardhat-verify插件来完成验证。因为步骤是分开的，所以在部署命令本身中不需要提供API密钥。
<!-- forge script script/DeployMathOps.sol:DeployMathOps \
--rpc-url $RPC_URL \  \\用于实际部署
--fork-url https://hoodi.infura.io/v3/b6a39ba8bb49482fbef08826773901cc \  \\用于本地模拟部署---与rpc-url互斥使用
--private-key $PRIVATE_KEY \
--broadcast \
--verify \
--etherscan-api-key 《etherscan-api-key》 \
-vvv -->
forge script script/DeployMathOps.sol:DeployMathOps \
--rpc-url https://hoodi.infura.io/v3/b6a39ba8bb49482fbef08826773901cc \
--private-key 3a240ce3cd5b1860f9ded009a932ecad2cd60f08088df1d23aa1d614cc225106 \
--broadcast \
-vvv

* 部署结果：
chenfeng@CF:/mnt/c/MySpace/code/web3/my/task/contract-pratice-task/task03-foundry$ forge script script/DeployMathOps.sol:DeployMathOps --rpc-url https://hoodi.infura.io/v3/b6a39ba8bb49482fbef08826773901cc --private-key 3a240ce3cd5b1860f9ded009a932ecad2cd60f08088df1d23aa1d614cc225106 --broadcast -vvv
[⠊] Compiling...
[⠰] Compiling 1 files with Solc 0.8.30
[⠔] Solc 0.8.30 finished in 296.46ms
Compiler run successful!
Script ran successfully.

== Logs ==
  MathOps deployed at: 0xC8116fF1858e0301af5E26E671745338d0256604

## Setting up 1 EVM.

==========================

Chain 560048

Estimated gas price: 2.667008924 gwei

Estimated total gas used for script: 334172

Estimated amount required: 0.000891239706150928 ETH

==========================

##### hoodi
✅  [Success] Hash: 0xfc5abe414b519b8e0994ccc9159c57282506c06d7169886edf9abc41bf00406e
Contract Address: 0xC8116fF1858e0301af5E26E671745338d0256604
Block: 1151350
Paid: 0.000396638928229184 ETH (257056 gas * 1.543005914 gwei)

✅ Sequence #1 on hoodi | Total Paid: 0.000396638928229184 ETH (257056 gas * avg 1.543005914 gwei)
                                                                                                                                                                                

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /mnt/c/MySpace/code/web3/my/task/contract-pratice-task/task03-foundry/broadcast/DeployMathOps.sol/560048/run-latest.json

Sensitive values saved to: /mnt/c/MySpace/code/web3/my/task/contract-pratice-task/task03-foundry/cache/DeployMathOps.sol/560048/run-latest.json