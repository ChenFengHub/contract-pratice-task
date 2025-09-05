// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MathOps.sol";

contract DeployMathOps is Script {
    function run() external {
        // 获取部署者私钥
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey);
        // 不设置，则自动使用命令行提供的私钥
        vm.startBroadcast();
        
        // 部署合约
        MathOps math = new MathOps();
        
        vm.stopBroadcast();
        
        // 记录部署地址
        console.log("MathOps deployed at:", address(math));
    }
}