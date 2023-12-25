module coin_swap::swapped_coin_bak {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::tx_context::TxContext;
    // Use this dependency to get a type wrapper for UTF-8 strings
    use std::string::{Self, String};

    const ENotTheSameCurrency: u64 = 0;

    const ENotEnoughBalance: u64 = 1;

    const ESelfTransfer: u64 = 2;

    const EInvalidExchangeFee: u16 = 3;

    struct CoinAdminCap has key { id: UID }

    struct UserCap has key {
        id: UID,
        kycStatus: String
    }

    struct Pocket has key {
        id: UID,
        currency: String,
        type: String,
        balance: u16,
        owner: address
    }

    struct Transfer has key {
        id: UID,
        currency: String,
        type: String,
        from: address,
        to: address,
        note: String
    }

    struct UserInfo has key {
        id: UID,
        // CreatedTime, user address, etc
        user_address: address,
        kyc: bool,
        profile_pic_url: String
    }

    struct AuthenticationManager has key {
        id: UID,
        users: Table<address, UserInfo>
    }

    struct ExchangeRatePublisher has key {
        id: UID,
        //price: u64, // There should be a mapping of different currency pair and its rates
        fee: u64,
        rate: u64
    }

    fun init(ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        transfer::share_object(ExchangeRatePublisher {
            id: object::new(ctx),
            fee: 50
        }, admin_address);

        transfer::transfer(CoinAdminCap {
            id: object::new(ctx)
        }, admin_address);
        // Shared authentication manager
        transfer::transfer(AuthenticationManager {
            id: object::new(ctx),
            allowed: bag::new(ctx),
            banned: bag::new(ctx)
        }, admin_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"USD"),
            type: string::utf8(b"individual"),
            balance: 0,
            owner: tx_context::sender(ctx)
        }, admin_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"EUR"),
            type: string::utf8(b"individual"),
            balance: 0,
            owner: tx_context::sender(ctx)
        }, admin_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"PLN"),
            type: string::utf8(b"individual"),
            balance: 0,
            owner: tx_context::sender(ctx)
        }, admin_address);
    }

    /// Authentication service
    public fun signup_new_user(user_address: address, authentication_manager: &mut AuthenticationManager, ctx: &mut TxContext) {
        if (table::contains<address, UserInfo>(&mut authentication_manager.users, user_address)) {
            // The user is already created
            
        } else {
            let new_user_info = UserInfo {
                id: object::new(ctx),
                user_address: user_address,
                kyc: true,
                profile_pic_url: string::utf8(b""initial_profile_pic")
            };
            table::add(&mut authentication_manager.users, new_user, new_user_info);
            transfer::transfer(UserCap {
                id: object::new(ctx)
            }, new_user);
        }
    }

    fun user_exists(user_address: address) {

    }

    public fun update_profile_picture(_: &UserCap, user_address: address, profile_pic: String, ctx: &mut TxContext) {
        
    }

    /// Closed-loop coin number control
    public entry fun create_transfer(_: &UserCap, from_pocket: &mut Pocket, to_pocket: &mut Pocket, amount: u16, currency: String) {
        assert!(from_pocket.currency == to_pocket.currency, ENotTheSameCurrency);
        assert!(from_pocket.balance > amount, ENotEnoughBalance);
        assert!(from_pocket.owner != to_pocket.owner, ESelfTransfer);
        from_pocket.balance = from_pocket.balance - amount;
        to_pocket.balance = to_pocket.balance + amount;
    }
    
    /// Mints new coins with requested currency
    public fun mint(_: &CoinAdminCap, pocket: &mut Pocket, amount: u16, currency: String) {
        // Should check whether requested currency matches the symbol of the pocket
        assert!(pocket.currency == currency, ENotTheSameCurrency);
        pocket.balance = pocket.balance + amount;
    }

    /// Destroys new coins with requested currency
    public fun destroy(_: &CoinAdminCap, pocket: &mut Pocket, amount: u16, currency: String) {
        assert!(pocket.currency == currency, ENotTheSameCurrency);
        assert!(pocket.balance > amount, ENotEnoughBalance);
        pocket.balance = pocket.balance - amount;
    }

    /// Exchange service
    /// 
    /// 
    /// 
    public fun update_rate(_: &CoinAdminCap, rate: u16) {

    }

    public fun update_fee(_: &CoinAdminCap, publisher: &mut ExchangeRatePublisher, fee: u16) {
        assert!(fee > 0, EInvalidExchangeFee);
        publisher.fee = fee;
    }

    public fun add_currency_pair(_: &CoinAdminCap) {
        /// Data structure:
        /// {
        ///  "EURUSD": {
        ///     "left": 1.05,
        ///     "right": 0.95
        ///   }
        /// 
        ///}
    }

    public fun remove_currency_pair(_: &CoinAdminCap) {

    }
    
    public fun request_exchange(_: &UserCap, from: &mut Pocket, to: &mut Pocket, amount: u16) {

    }
}
