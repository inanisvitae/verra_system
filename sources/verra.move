module verra_system::verra {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self};
    use sui::table::{Table, Self};
    use sui::dynamic_field as df;
    use sui::math;
    use std::string::{Self, String};

    const ENotTheSameCurrency: u64 = 0;

    const ENotEnoughBalance: u64 = 1;

    const ESelfTransfer: u64 = 2;

    const EMinusTransferAmount: u64 = 3;

    const ENotIndendedReceiver: u64 = 4;

    const ECurrencyPairNotExist: u64 = 5;

    const ECurrencyPairExist: u64 = 5;

    struct CreateTransferEvent has copy, drop {
        from: address,
        to: address,
        description: String,
        amount: u64,
        currency: String
    }

    struct AcceptTransferEvent has copy, drop {
        from: address,
        to: address,
        description: String,
        amount: u64,
        currency: String
    }

    struct CoinAdminCap has key {
        id: UID,
        description: String
    }

    struct Pocket has key, store {
        id: UID,
        currency: String,
        type: String,
        balance: u64,
        owner: address
    }

    struct UserCap has key {
        id: UID,
        description: String
    }

    struct UserInfo has key {
        id: UID,
        // CreatedTime, user address, etc
        user_address: address,
        profile_pic_url: String,
        type: String
    }

    struct Transfer has key {
        id: UID,
        from: address,
        to: address,
        description: String,
        amount: u64,
        currency: String
    }

    struct ExchangeRatePublisher has key, store {
        id: UID,
        fee: u64,
        description: String,
        source_url: String
    }

    fun init(ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        transfer::transfer(CoinAdminCap {
            id: object::new(ctx),
            description: string::utf8(b"Admin level capability")
        }, admin_address);

        create_user(admin_address, string::utf8(b"random profile pic"), admin_type(), ctx);

        // Creates a new rate publisher
        let exchange_rate_publisher = ExchangeRatePublisher {
            id: object::new(ctx),
            fee: 1,
            description: string::utf8(b"A new exchange rate publisher"),
            source_url: string::utf8(b"A source url to forex price exchange")
        };
        let rates = table::new<String, u64>(ctx);
        df::add(&mut exchange_rate_publisher.id, publisher_rates(), rates);
        let pockets = table::new<String, Pocket>(ctx);
        table::add(&mut pockets, string::utf8(b"PLN"), Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"PLN"),
            type: admin_type(),
            balance: 0,
            owner: tx_context::sender(ctx)
        });
        table::add(&mut pockets, string::utf8(b"USD"), Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"USD"),
            type: admin_type(),
            balance: 0,
            owner: tx_context::sender(ctx)
        });
        table::add(&mut pockets, string::utf8(b"EUR"), Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"EUR"),
            type: admin_type(),
            balance: 0,
            owner: tx_context::sender(ctx)
        });
        df::add(&mut exchange_rate_publisher.id, publisher_pockets(), pockets);

        transfer::share_object(exchange_rate_publisher);
    }

    /// Signs up a user when user requests it. For simplicity, we auto-verify the user and create
    /// user cap and transfer it to the user.
    public entry fun create_user(user_address: address,
                                profile_pic_url: String,
                                type: String,
                                ctx: &mut TxContext) {
        let description = if (type == individual_type()) {
            string::utf8(b"User leve capability")
        } else if (type == admin_type()) {
            string::utf8(b"Admin leve capability")
        } else {
            string::utf8(b"Error")
        };
        transfer::transfer(UserCap {
            id: object::new(ctx),
            description
        }, user_address);
        transfer::transfer(UserInfo {
            id: object::new(ctx),
            user_address,
            profile_pic_url,
            type
        }, user_address);

        create_pockets(user_address, type, ctx);
    }

    /// Creates corresponding pockets for each new user
    fun create_pockets(user_address: address, type: String, ctx: &mut TxContext) {
        // Initialize empty pockets with different currencies for admin
        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"USD"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"EUR"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);

        transfer::transfer(Pocket {
            id: object::new(ctx),
            currency: string::utf8(b"PLN"),
            type,
            balance: 0,
            owner: tx_context::sender(ctx)
        }, user_address);
    }

    // Series of user function to update user info object
    public entry fun update_profile_pic_url(_: &UserCap, user_info: &mut UserInfo, new_profile_pic_url: String) {
        user_info.profile_pic_url = new_profile_pic_url;
    }

    fun individual_type(): (String) { string::utf8(b"individual") }
    fun admin_type(): (String) { string::utf8(b"admin") }
    fun publisher_rates(): (String) { string::utf8(b"rates") }
    fun publisher_pockets(): (String) { string::utf8(b"pockets") }

    public entry fun create_transfer(_: &UserCap,
                                    from_pocket: &mut Pocket,
                                    to: address,
                                    description: String,
                                    amount: u64,
                                    currency: String,
                                    ctx: &mut TxContext) {
        let from = tx_context::sender(ctx);
        assert!(amount > 0, EMinusTransferAmount);
        assert!(from_pocket.balance - amount >= 0, ENotEnoughBalance);
        assert!(from != to, ESelfTransfer);
        from_pocket.balance = from_pocket.balance - amount;
        transfer::transfer(Transfer {
            id: object::new(ctx),
            from,
            to,
            description,
            amount,
            currency
        }, to);
        event::emit(CreateTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    public entry fun accept_transfer(_: &UserCap, pocket: &mut Pocket, transfer: Transfer) {
        let Transfer {
            id,
            from,
            to,
            description,
            amount,
            currency
        } = transfer;
        assert!(from != pocket.owner, ESelfTransfer);
        assert!(pocket.currency == currency, EMinusTransferAmount);
        assert!(to == pocket.owner, ENotIndendedReceiver);

        pocket.balance = pocket.balance + amount;
        object::delete(id);

        event::emit(AcceptTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    /// Method for only coinadmin
    fun create_admin_transfer_(_: &CoinAdminCap,
                            from_pocket: &mut Pocket,
                            to: address,
                            description: String,
                            amount: u64,
                            currency: String,
                            ctx: &mut TxContext) {
        let from = tx_context::sender(ctx);
        assert!(amount > 0, EMinusTransferAmount);
        assert!(from_pocket.balance - amount >= 0, ENotEnoughBalance);
        assert!(from != to, ESelfTransfer);
        from_pocket.balance = from_pocket.balance - amount;
        transfer::transfer(Transfer {
            id: object::new(ctx),
            from,
            to,
            description,
            amount,
            currency
        }, to);
        event::emit(CreateTransferEvent {
            from,
            to,
            description,
            amount,
            currency
        });
    }

    // Mints a new balance and deposit it into the pockets of 
    public entry fun topup_exchange(_: &CoinAdminCap,
                                    publisher: &mut ExchangeRatePublisher,
                                    currency: String,
                                    amount: u64) {
        // Simply adds balance change to one of the pockets in topup exchange
        let pockets: &mut Table<String, Pocket> = df::borrow_mut(&mut publisher.id, publisher_pockets());
        let pocket: &mut Pocket = table::borrow_mut(pockets, currency);
        pocket.balance = pocket.balance + amount;
    }

    /// Mints new balance with requested currency for admin pocket
    public entry fun mint(admin_cap: &CoinAdminCap,
                        pocket: &mut Pocket,
                        to: address,
                        amount: u64,
                        currency: String,
                        ctx: &mut TxContext) {
        // Should check whether requested currency matches the symbol of the pocket
        assert!(pocket.currency == currency, ENotTheSameCurrency);
        assert!(to != pocket.owner, ESelfTransfer);
        pocket.balance = pocket.balance + amount;
        let description = string::utf8(b"Admin topup");
        // Then a new transfer should be created to be sent to the destination
        create_admin_transfer_(admin_cap, pocket, to, description, amount, currency, ctx);
    }

    public fun update_fee(_: &CoinAdminCap, publisher: &mut ExchangeRatePublisher, fee: u64) {
        // We charge a flat fee for the purpose of thesis
        publisher.fee = fee;
    }

    public fun add_currency_pair(_: &CoinAdminCap,
                                initial_rate: u64,
                                currency_pair: String,
                                publisher: &mut ExchangeRatePublisher) {
        let rates: &mut Table<String, u64> = df::borrow_mut(&mut publisher.id, publisher_rates());
        assert!(!table::contains<String, u64>(rates, currency_pair), ECurrencyPairExist);
        table::add(rates, currency_pair, initial_rate);
    }

    public fun remove_currency_pair(_: &CoinAdminCap,
                                    currency_pair: String,
                                    publisher: &mut ExchangeRatePublisher) {
        let rates: &mut Table<String, u64> = df::borrow_mut(&mut publisher.id, publisher_rates());
        assert!(table::contains<String, u64>(rates, currency_pair), ECurrencyPairNotExist);
        table::remove(rates, currency_pair);
    }

    public entry fun update_rate(_: &CoinAdminCap,
                                publisher: &mut ExchangeRatePublisher,
                                currency_pair: String,
                                rate: u64) {
        let rates: &mut Table<String, u64> = df::borrow_mut(&mut publisher.id, publisher_rates());
        if (table::contains<String, u64>(rates, currency_pair)) {
            table::remove(rates, currency_pair);
        };
        table::add(rates, currency_pair, rate);
    }

    public entry fun request_exchange(_: &UserCap,
                                    from: &mut Pocket, // Source pocket belonging to the user
                                    to: &mut Pocket, // Destination pocket belonging to the user
                                    publisher: &mut ExchangeRatePublisher,
                                    currency_pair: String,
                                    source_currency: String,
                                    converted_currency: String,
                                    amount: u64) {
        // Checks whether currency_pair exists
        let rates_immutable: &Table<String, u64> = df::borrow(&publisher.id, publisher_rates());
        assert!(table::contains<String, u64>(rates_immutable, currency_pair), ECurrencyPairNotExist);
        // Checks whether from Pocket has enough balance
        assert!(from.balance >= (amount + publisher.fee), ENotEnoughBalance);
        // Checks whether from Pocket has the same currency type and to Pocket is the converted_currency
        assert!(from.currency == source_currency, ENotTheSameCurrency);
        assert!(to.currency == converted_currency, ENotTheSameCurrency);
        let rates: &mut Table<String, u64> = df::borrow_mut(&mut publisher.id, publisher_rates());
        let rate = table::borrow(rates, currency_pair);
        let outbound_amount = math::divide_and_round_up(amount * (*rate), 100);
        std::debug::print(&outbound_amount);
        // Deduct outbound amount from user's pocket
        from.balance = from.balance - (amount + publisher.fee);
        // Obtains pockets book from publisher
        let pockets: &mut Table<String, Pocket> = df::borrow_mut(&mut publisher.id, publisher_pockets());
        let publisher_source_currency_pocket: &mut Pocket = table::borrow_mut(pockets, source_currency);
        // Adds the amount to publisher's correct pocket
        publisher_source_currency_pocket.balance = publisher_source_currency_pocket.balance + amount;
        let publisher_converted_currency_pocket: &mut Pocket = table::borrow_mut(pockets, converted_currency);
        // Sends outbound amount from publisher pocket to user
        publisher_converted_currency_pocket.balance = publisher_converted_currency_pocket.balance - outbound_amount;
        // Adds the amount to user's destination pocket
        to.balance = to.balance + outbound_amount;
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    public fun get_admin_cap(self: &CoinAdminCap): String {
        self.description
    }

    public fun get_pocket(self: &Pocket): (String, String, u64, address) {
        (self.currency, self.type, self.balance, self.owner)
    }

    public fun get_user_info(self: &UserInfo): (address, String, String) {
        (self.user_address, self.profile_pic_url, self.type)
    }

    public fun get_transfer(self: &Transfer): (address, address, String, u64, String) {
        (self.from, self.to, self.description, self.amount, self.currency)
    }

    public fun get_publisher(self: &ExchangeRatePublisher): (&Table<String, u64>, &Table<String, Pocket>) {
        let rates = df::borrow(&self.id, publisher_rates());
        let pockets = df::borrow(&self.id, publisher_pockets());
        (rates, pockets)
    }
}
