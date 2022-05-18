// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Collector {
    uint256 maintenanceTax; // maintenance and tax, 10 Ether
    uint256 prevMaintenance; // 6 months period
    uint256 prevDivident;
    uint256 prevSalary;
    uint256 fee; //fixed 100 Ether. participation
    uint256 CarID; //32 digit 
    uint256 public balance;
    address[] addresses;
    address private manager;

    address payable Dealer;

    function SetCarDealer(address payable newDealer) public checkManager {
        Dealer = newDealer;
    }

    struct TaxiDriver {
        address payable Id;
        uint256 salary;
        uint256 balance;
        uint256 approvalState;
        bool checkApproval;
        uint256 prevSalary;
    }

    TaxiDriver Driver;

    struct Proposal {
        uint32 CarId;
        uint256 price;
        uint256 validTime;
        uint256 approvalState;
    }

    Proposal proposedMiat;
    Proposal proposedRepurchase;

    struct Participant {
        address adrs;
        uint256 bal;
    }

    mapping (address => Participant) participants;

    //check user voted or not for current propose;
    mapping (address => bool) driverVote;
    mapping (address => bool) carVote;
    mapping (address => bool) repurchaseVote;

    constructor() {
        manager = msg.sender;
        balance = 0;
        maintenanceTax = 10 ether;
        prevMaintenance = block.timestamp;
        prevDivident = block.timestamp;
        prevSalary = block.timestamp;
        fee = 100 ether;
    }

    /*receive() payable external {
        balance += msg.value;
    }*/

    modifier checkManager() {
        require(msg.sender == manager, "Not manager");
        _;
    }

    modifier checkDriver() {
        require(msg.sender == Driver.Id, "Not driver");
        _;
    }

    modifier checkParticipant() {
        require(participants[msg.sender].adrs != address(0), "Not participant");
        _;
    }

    function Join() public payable {
        require(addresses.length < 9, "Max 9");
        require(participants[msg.sender].adrs == address(0), "Already joined");
        require(msg.value >= fee, "Need 100 ether to join");
        participants[msg.sender] = Participant(msg.sender, 0 ether);
        addresses.push(msg.sender);
        balance = balance + fee;
        uint256 payback = msg.value - fee;
        if(payback > 0){
            payable(msg.sender).transfer(payback);
        }
    }

    modifier checkDealer() {
        require(msg.sender == Dealer, "Not Dealer");
        _;
    }

    function CarProposeToBusiness(uint32 id, uint price, uint validTime) public checkDealer {
        require(CarID == 0, "Already a car");
        proposedMiat = Proposal(id, price, validTime, 0);
        for(uint256 i = 0; i < addresses.length; i++) {
            carVote[addresses[i]] = false;
        }
    }

    function ApprovePurchaseCar() public checkParticipant {
        require(!carVote[msg.sender], "Already voted");
        proposedMiat.approvalState = proposedMiat.approvalState + 1;
        carVote[msg.sender] = true;
        PurchaseCar();
    }

    function PurchaseCar() private {
        require(balance >= proposedMiat.price, "Not enough mone");
        require(block.timestamp <= proposedMiat.validTime, "Not in valid time");
        require(proposedMiat.approvalState > (addresses.length/2), "Not approved by others");
        balance = balance - proposedMiat.price;
        if(!Dealer.send(proposedMiat.price)) {
            balance = balance + proposedMiat.price;
            revert();
        }
        CarID = proposedMiat.CarId;
    }

    function RepurchaseCarPropose(uint32 id, uint price, uint validTime) public checkDealer {
        require(CarID == id, "Not business car");
        proposedRepurchase = Proposal(id, price, validTime, 0);
        for(uint256 i = 0; i < addresses.length; i++) {
            repurchaseVote[addresses[i]] = false;
        }
    }

    function ApproveSellProposal() public checkParticipant {
        require(!repurchaseVote[msg.sender], "Already voted");
        proposedRepurchase.approvalState = proposedRepurchase.approvalState + 1;
        repurchaseVote[msg.sender] = true;
    }

    function RepurchaseCar() public payable checkDealer {
        require(msg.value >= proposedRepurchase.price, "Not enough mune");
        require(block.timestamp <= proposedRepurchase.validTime, "not in valid time");
        require(proposedRepurchase.approvalState > (addresses.length/2),"not enough approval");
        uint256 payback = msg.value - proposedRepurchase.price;
        if(payback>0){
            payable(msg.sender).transfer(payback);
        }
        balance = balance + msg.value - payback;
        delete CarID;
    }

    function ProposeDriver(address payable addr, uint256 muneh) public checkManager {
        require(!Driver.checkApproval, "Driver exists");
        Driver = TaxiDriver(addr, muneh, 0, 0, false, block.timestamp);
        uint256 i = 0;
        while(i < addresses.length){
            driverVote[addresses[i]] = false;
        }
    }

    function ApproveDriver() public checkParticipant {
        require(!driverVote[msg.sender], "Already voted");
        Driver.approvalState = Driver.approvalState + 1;
        driverVote[msg.sender] = true;
    }

    function SetDriver() public checkManager {
        require(Driver.approvalState > (addresses.length/2), "Half or more did not approve");
        require(Driver.checkApproval, "Already driver");
        require(Driver.Id != address(0), "No driver");
        Driver.checkApproval = true;
    }

    function ProposeFireDriver() public checkParticipant {
        require(Driver.checkApproval, "No driver");
        require(!driverVote[msg.sender], "Already voted");
        Driver.approvalState = Driver.approvalState + 1;
        FireDriver();
    }

    function FireDriver() public {
        require(Driver.checkApproval, "No driver");
        require(Driver.approvalState > (addresses.length/2), "Half or more did not approve");
        balance = balance - Driver.salary;
        if(!payable(Driver.Id).send(Driver.salary)){
            balance = balance + Driver.salary;
            revert();
        }
        delete Driver;
    }

    function LeaveJob() public checkDriver {
        FireDriver();
    }

    function GetCharge() public payable {
        balance = balance + msg.value;
    }

    function GetSalary() public checkDriver {
        require(block.timestamp - prevSalary >= 2629746, "1 month have not passed");
        require(Driver.balance > 0, "Empty balance of driver");
        payable(Driver.Id).transfer(Driver.balance);
        Driver.balance = 0;
    }

    function CarExpenses() public checkManager {
        require(block.timestamp - prevMaintenance >= 15778463, "6 months has not passed");
        require(CarID != 0, "No car exists");
        require(balance >= maintenanceTax, "Balance is not enough to pay for expenses");
        balance = balance - maintenanceTax;
        if(!Dealer.send(maintenanceTax)){
            balance = balance + maintenanceTax;
            revert();
        }
    }

    function PayDivident() public payable checkManager {
        require(block.timestamp - prevDivident >= 15778463, "6 months has not passed");
        require(balance > 0, "Not enough money");
        require(balance > fee * addresses.length, "No profit");
        uint256 divident = ((balance - (fee * addresses.length)) / addresses.length);
        uint256 i = 0;
        while(i < addresses.length){
            participants[addresses[i]].bal += divident;
        }
        balance = 0;
        prevDivident = block.timestamp;
    }

    function GetDivident() public payable checkParticipant {
        require(participants[msg.sender].bal > 0, "No money in balance");
        if(!payable(msg.sender).send(participants[msg.sender].bal)){
            revert();
        }
        participants[msg.sender].bal = 0;
    }
    
    /*function withdraw(uint amount, address payable destAddr) public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(amount <= balance, "Not enough funds!");
        
        destAddr.transfer(amount);
        balance -= amount;
    }*/

    fallback () external payable {
        
    }
    receive() external payable {

    }
}