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