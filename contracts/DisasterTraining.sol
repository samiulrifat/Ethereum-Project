// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract DisasterTraining {

    enum UserRole { None, Admin, Trainer, Participant }
    enum TrainingInterest { None, first_aid, shelter_rebuild, food_safety }

    uint public constant BOOKING_FEE = 0.025 ether;

    struct Participant {
        uint id;
        string name;
        uint age;
        string gender;
        string district;
        TrainingInterest training_interest;
        bool has_completed_training;
        address wallet;
    }

    struct TrainerSchedule {
        mapping(uint8 => address) slotToParticipant; // slot index to participant address
    }

    mapping(address => UserRole) public userRoles;
    address[] public admins;
    mapping(address => Participant) public participants;
    mapping(address => TrainerSchedule) private trainerSchedules;

    event ParticipantRegistered(address participant, uint id);
    event TrainerRegistered(address trainer);
    event AdminRegistered(address admin);
    event DataUpdated(address participant, string field);
    event TrainingBooked(address participant, address trainer, uint8 slot);

    modifier onlyAdmin() {
        require(userRoles[msg.sender] == UserRole.Admin, "Only Admin allowed");
        _;
    }

    modifier onlyParticipant() {
        require(userRoles[msg.sender] == UserRole.Participant, "Only Participant allowed");
        _;
    }

    // Registration functions
    function registerAsAdmin() external {
        require(userRoles[msg.sender] == UserRole.None, "Already registered");
        userRoles[msg.sender] = UserRole.Admin;
        admins.push(msg.sender);
        emit AdminRegistered(msg.sender);
    }

    function registerAsTrainer() external {
        require(userRoles[msg.sender] == UserRole.None, "Already registered");
        userRoles[msg.sender] = UserRole.Trainer;
        // No additional data needed for trainers
        emit TrainerRegistered(msg.sender);
    }

    function registerAsParticipant(
        uint _id,
        string calldata _name,
        uint _age,
        string calldata _gender,
        string calldata _district,
        uint8 _interest
    ) external {
        require(userRoles[msg.sender] == UserRole.None, "Already registered");
        require(_interest >= 1 && _interest <= 3, "Invalid interest selected");
        
        participants[msg.sender] = Participant({
            id: _id,
            name: _name,
            age: _age,
            gender: _gender,
            district: _district,
            training_interest: TrainingInterest(_interest),
            has_completed_training: false,
            wallet: msg.sender
        });
        userRoles[msg.sender] = UserRole.Participant;
        emit ParticipantRegistered(msg.sender, _id);
    }

    // Admin can update certain fields
    function updateParticipant(
        address participantAddr,
        uint8 newInterest,
        bool setCompleted
    ) external onlyAdmin {
        Participant storage p = participants[participantAddr];

        if (newInterest != 0) {
            require(newInterest >= 1 && newInterest <= 3, "Invalid training interest");
            p.training_interest = TrainingInterest(newInterest);
            emit DataUpdated(participantAddr, "interest");
        }
        if (setCompleted) {
            require(!p.has_completed_training, "Already completed");
            p.has_completed_training = true;
            emit DataUpdated(participantAddr, "hasCompletedTraining");
        } else {
            require(!setCompleted, "Completion cannot be reverted");
        }
    }

    // Book a training slot with a trainer
    // slots: 1: 9:00–9:30, 2: 9:31–10:00, 3: 10:01–10:30
    function bookTrainingSlot(address trainer, uint8 slotIndex) external payable onlyParticipant {
        require(userRoles[trainer] == UserRole.Trainer, "Not a valid trainer");
        require(slotIndex >= 1 && slotIndex <= 3, "Invalid slot");
        require(msg.value == BOOKING_FEE, "Incorrect fee");
        TrainerSchedule storage ts = trainerSchedules[trainer];
        require(ts.slotToParticipant[slotIndex] == address(0), "Trainer already booked");

        ts.slotToParticipant[slotIndex] = msg.sender;
        // Send the fee to admin 
        payable(admins[0]).transfer(msg.value);

        emit TrainingBooked(msg.sender, trainer, slotIndex);
    }

    // View a trainer's schedule
    function viewTrainerSchedule(address trainer) public view returns (address[3] memory) {
        require(userRoles[trainer] == UserRole.Trainer, "Not a trainer");
        address[3] memory slots;
        for (uint8 i = 1; i <= 3; i++) {
            slots[i-1] = trainerSchedules[trainer].slotToParticipant[i];
        }
        return slots;
    }
}
