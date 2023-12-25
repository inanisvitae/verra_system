#[test_only]
module verra_system::tests {
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use std::string::{Self, String};
    use sui::dynamic_field as df;
    use sui::table::{Table, Self};

    fun scenario(): Scenario { test_scenario::begin(@0xAbc) }
    fun people(): (address, address, address) { (@0xAbc, @0xE05, @0xFACE) }
    fun fixed_url(): (String) { string::utf8(b"Random Url") }
    fun individual_type(): (String) { string::utf8(b"individual") }
    fun admin_type(): (String) { string::utf8(b"admin") }
    fun fixed_amount(): u16 { 90 }
    fun one_third_fixed_amount(): u16 { 30 }
    fun two_thirds_fixed_amount(): u16 { fixed_amount() - one_third_fixed_amount() }
    fun pln_symbol(): (String) { string::utf8(b"PLN") }
    fun usd_symbol(): (String) { string::utf8(b"USD") }
    fun eur_symbol(): (String) { string::utf8(b"EUR") }
    fun transfer_description(): (String) { string::utf8(b"A new transfer is created") }

    const EVerraCoinInitFailed: u64 = 0;

    #[test]
    fun test_scenarios() {
        // Initialize a mock sender address
        let (admin, first_person, second_person) = people();
    
        // Begins a multi transaction scenario with admin as the sender
        let scenario = scenario();
        std::debug::print(&scenario);
        {
            verra_system::verra::init_for_testing(ctx(&mut scenario))
        };

        next_tx(&mut scenario, admin);
        {
            let coinadmincap = test_scenario::take_from_sender<verra_system::verra::CoinAdminCap>(&scenario);
            std::debug::print(&coinadmincap);
            let (description) = verra_system::verra::get_admin_cap(&coinadmincap);
            assert!(description == string::utf8(b"Admin level capability"), 0);
            test_scenario::return_to_address<verra_system::verra::CoinAdminCap>(admin, coinadmincap);

            let pocket1 = test_scenario::take_from_sender<verra_system::verra::Pocket>(&scenario);
            let (currency, type, balance, owner) = verra_system::verra::get_pocket(&pocket1);
            assert!(currency == string::utf8(b"PLN"), 0);
            assert!(type == admin_type(), 0);
            let pocket2 = test_scenario::take_from_sender<verra_system::verra::Pocket>(&scenario);
            let pocket3 = test_scenario::take_from_sender<verra_system::verra::Pocket>(&scenario);
            
            std::debug::print(&pocket1);
            std::debug::print(&pocket2);
            std::debug::print(&pocket3);

            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, pocket1);
            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, pocket2);
            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, pocket3);

        };

        // Create user for first_person
        next_tx(&mut scenario, first_person);
        {
            verra_system::verra::create_user(first_person, fixed_url(), individual_type(), ctx(&mut scenario));
        };

        // Create user for second_person
        next_tx(&mut scenario, second_person);
        {
            verra_system::verra::create_user(second_person, fixed_url(), individual_type(), ctx(&mut scenario));
        };

        // Tests the newly created user cap
        {
            let usercap = test_scenario::take_from_address<verra_system::verra::UserCap>(&scenario, first_person);
            std::debug::print(&usercap);
            test_scenario::return_to_address<verra_system::verra::UserCap>(first_person, usercap);
        };

        // Tests the newly created user info
        {
            let userinfo = test_scenario::take_from_address<verra_system::verra::UserInfo>(&scenario, first_person);
            let (user_address, profile_pic_url, type) = verra_system::verra::get_user_info(&userinfo);

            std::debug::print(&userinfo);
            assert!(user_address == first_person, 0);
            assert!(profile_pic_url == fixed_url(), 0);
            assert!(type == individual_type(), 0);
            test_scenario::return_to_address<verra_system::verra::UserInfo>(first_person, userinfo);
        };

        // No need to verify everything again for second person

        // Mint for first person
        next_tx(&mut scenario, admin);
        {
            std::debug::print(&(string::utf8(b"====== Mint and create transfer to first person")));
            let coinadmincap = test_scenario::take_from_address<verra_system::verra::CoinAdminCap>(&scenario, admin);
            let admin_usd_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, admin);
            let admin_eur_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, admin);
            let admin_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, admin);

            std::debug::print(&admin_pln_pocket);

            verra_system::verra::mint(&coinadmincap, &mut admin_pln_pocket, first_person, fixed_amount(), pln_symbol(), ctx(&mut scenario));

            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, admin_usd_pocket);
            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, admin_eur_pocket);
            test_scenario::return_to_address<verra_system::verra::Pocket>(admin, admin_pln_pocket);

            test_scenario::return_to_address<verra_system::verra::CoinAdminCap>(admin, coinadmincap);
        };

        next_tx(&mut scenario, first_person);
        {
            std::debug::print(&(string::utf8(b"====== Accept pln transfer for first person")));
            let usercap = test_scenario::take_from_address<verra_system::verra::UserCap>(&scenario, first_person);
            let incoming_transfer = test_scenario::take_from_address<verra_system::verra::Transfer>(&scenario, first_person);
            let (from, to, description, amount, currency) = verra_system::verra::get_transfer(&incoming_transfer);
            assert!(from == admin, 0);
            assert!(to == first_person, 0);
            assert!(description == string::utf8(b"Admin topup"), 0);
            assert!(amount == fixed_amount(), 0);
            assert!(currency == pln_symbol(), 0);
            let first_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, first_person);
            // Calls accept_transfer()
            verra_system::verra::accept_transfer(&usercap, &mut first_person_pln_pocket, incoming_transfer);

            test_scenario::return_to_address<verra_system::verra::Pocket>(first_person, first_person_pln_pocket);
            test_scenario::return_to_address<verra_system::verra::UserCap>(first_person, usercap);
        };

        next_tx(&mut scenario, first_person);
        {
            // Verify the pln pocket for the first person
            std::debug::print(&(string::utf8(b"====== Creates transfer to second person")));
            let first_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, first_person);
            let usercap = test_scenario::take_from_address<verra_system::verra::UserCap>(&scenario, first_person);
            std::debug::print(&first_person_pln_pocket);
            let (_, _, balance, _) = verra_system::verra::get_pocket(&first_person_pln_pocket);
            assert!(balance == fixed_amount(), 0);
            // Creates transfer to second person
            verra_system::verra::create_transfer(&usercap, &mut first_person_pln_pocket, second_person, transfer_description(), one_third_fixed_amount(), pln_symbol(), ctx(&mut scenario));

            test_scenario::return_to_address<verra_system::verra::Pocket>(first_person, first_person_pln_pocket);
            test_scenario::return_to_address<verra_system::verra::UserCap>(first_person, usercap);
        };

        next_tx(&mut scenario, second_person);
        {
            // Test create_transfer
            std::debug::print(&(string::utf8(b"====== Test Scenario for create_transfer()")));
            let created_transfer = test_scenario::take_from_address<verra_system::verra::Transfer>(&scenario, second_person);
            std::debug::print(&created_transfer);
            let (from, to, description, amount, currency) = verra_system::verra::get_transfer(&created_transfer);
            assert!(description == transfer_description(), 0);
            assert!(to == second_person, 0);
            assert!(from == first_person, 0);
            assert!(amount == one_third_fixed_amount(), 0);
            let second_person_usercap = test_scenario::take_from_address<verra_system::verra::UserCap>(&scenario, second_person);
            let first_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, first_person);
            let second_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, second_person);
            // Accepts incoming transfer from first_person by calling accept_transfer()
            verra_system::verra::accept_transfer(&second_person_usercap, &mut second_person_pln_pocket, created_transfer);
            std::debug::print(&first_person_pln_pocket);
            std::debug::print(&second_person_pln_pocket);

            test_scenario::return_to_address<verra_system::verra::Pocket>(first_person, first_person_pln_pocket);
            test_scenario::return_to_address<verra_system::verra::Pocket>(second_person, second_person_pln_pocket);
            test_scenario::return_to_address<verra_system::verra::UserCap>(second_person, second_person_usercap);
        };

        next_tx(&mut scenario, second_person);
        {
            std::debug::print(&(string::utf8(b"====== Verfies the second person's and first person's pln pocket")));
            let first_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, first_person);
            let second_person_pln_pocket = test_scenario::take_from_address<verra_system::verra::Pocket>(&scenario, second_person);
            let (first_person_currency, _, first_person_balance, _) = verra_system::verra::get_pocket(&first_person_pln_pocket);
            let (second_person_currency, _, second_person_balance, _) = verra_system::verra::get_pocket(&second_person_pln_pocket);

            std::debug::print(&first_person_pln_pocket);
            std::debug::print(&second_person_pln_pocket);
            assert!(first_person_currency == second_person_currency, 0);
            assert!(first_person_balance == two_thirds_fixed_amount(), 0);
            assert!(second_person_balance == one_third_fixed_amount(), 0);

            test_scenario::return_to_address<verra_system::verra::Pocket>(first_person, first_person_pln_pocket);
            test_scenario::return_to_address<verra_system::verra::Pocket>(second_person, second_person_pln_pocket);
        };

        next_tx(&mut scenario, first_person);
        {
            // Requests for a forex exchange
            std::debug::print(&(string::utf8(b"====== Verifies the forex exchange rate publisher is initialized correctly")));
            let publisher = test_scenario::take_shared<verra_system::verra::ExchangeRatePublisher>(&scenario);
            std::debug::print(&publisher);
            let (rates, fees) = verra_system::verra::get_publisher(&publisher);
            std::debug::print(rates);
            assert!(table::length(rates) == 0, 0);
            std::debug::print(fees);
            assert!(table::length(fees) == 0, 0);

            test_scenario::return_shared<verra_system::verra::ExchangeRatePublisher>(publisher);
        };

        // Tests transfer
        // next_tx(&mut scenario, first_person);
        // {
        //     let sender_pln_pocket = test_scenario::take_from_sender<verra_system::verra::Pocket>(&scenario);
        //     std::debug::print(&pln_pocket);
        //     test_scenario::return_to_sender<verra_system::verra::Pocket>(&scenario, pln_pocket);

        // };

        test_scenario::end(scenario);
    }
}
