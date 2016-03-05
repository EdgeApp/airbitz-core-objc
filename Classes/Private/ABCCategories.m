//
//  ABCCategories.m
//  Airbitz
//

#import "ABCCategories.h"
#import "AirbitzCore+Internal.h"

@interface ABCCategories ()
{
    ABCAccount          *_account;
    NSArray             *_categoryList;
    BOOL                _categoriesUpdated;
}

@end

@implementation ABCCategories

- (id) initWithAccount:(ABCAccount *)account;
{
    _account = account;
    return self;
}

- (NSArray *)listCategories
{
    if (_categoryList && !_categoriesUpdated)
        return _categoryList;

    _categoriesUpdated = NO;
    char            **aszCategories = NULL;
    unsigned int    countCategories = 0;
    NSMutableArray *mutableArrayCategories = [[NSMutableArray alloc] init];
    
    // get the categories from the core
    tABC_Error error;
    ABC_GetCategories([_account.name UTF8String],
                      [_account.password UTF8String],
                      &aszCategories,
                      &countCategories,
                      &error);
    
    // If we've never added any categories, add them now
    if (countCategories == 0)
    {
        NSMutableArray *arrayCategories = [[NSMutableArray alloc] init];
        //
        // Expense categories
        //
        [arrayCategories addObject:NSLocalizedString(@"Expense:Air Travel", @"default category Expense:Air Travel")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Alcohol & Bars", @"default category Expense:Alcohol & Bars")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Allowance", @"default category Expense:Allowance")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Amusement", @"default category Expense:Amusement")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Arts", @"default category Expense:Arts")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:ATM Fee", @"default category Expense:ATM Fee")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Auto & Transport", @"default category Expense:Auto & Transport")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Auto Insurance", @"default category Expense:Auto Insurance")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Auto Payment", @"default category Expense:Auto Payment")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Baby Supplies", @"default category Expense:Baby Supplies")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Babysitter & Daycare", @"default category Expense:Babysitter & Daycare")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Bank Fee", @"default category Expense:Bank Fee")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Bills & Utilities", @"default category Expense:Bills & Utilities")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Books", @"default category Expense:Books")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Books & Supplies", @"default category Expense:Books & Supplies")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Car Wash", @"default category Expense:Car Wash")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Cash & ATM", @"default category Expense:Cash & ATM")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Charity", @"default category Expense:Charity")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Clothing", @"default category Expense:Clothing")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Coffee Shops", @"default category Expense:Coffee Shops")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Credit Card Payment", @"default category Expense:Credit Card Payment")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Dentist", @"default category Expense:Dentist")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Deposit to Savings", @"default category Expense:Deposit to Savings")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Doctor", @"default category Expense:Doctor")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Education", @"default category Expense:Education")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Electronics & Software", @"default category Expense:Electronics & Software")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Entertainment", @"default category Expense:Entertainment")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Eyecare", @"default category Expense:Eyecare")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Fast Food", @"default category Expense:Fast Food")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Fees & Charges", @"default category Expense:Fees & Charges")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Financial", @"default category Expense:Financial")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Financial Advisor", @"default category Expense:Financial Advisor")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Food & Dining", @"default category Expense:Food & Dining")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Furnishings", @"default category Expense:Furnishings")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Gas & Fuel", @"default category Expense:Gas & Fuel")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Gift", @"default category Expense:Gift")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Gifts & Donations", @"default category Expense:Gifts & Donations")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Groceries", @"default category Expense:Groceries")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Gym", @"default category Expense:Gym")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Hair", @"default category Expense:Hair")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Health & Fitness", @"default category Expense:Health & Fitness")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:HOA Dues", @"default category Expense:HOA Dues")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Hobbies", @"default category Expense:Hobbies")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home", @"default category Expense:Home")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home Improvement", @"default category Expense:Home Improvement")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home Insurance", @"default category Expense:Home Insurance")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home Phone", @"default category Expense:Home Phone")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home Services", @"default category Expense:Home Services")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Home Supplies", @"default category Expense:Home Supplies")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Hotel", @"default category Expense:Hotel")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Interest Exp", @"default category Expense:Interest Exp")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Internet", @"default category Expense:Internet")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:IRA Contribution", @"default category Expense:IRA Contribution")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Kids", @"default category Expense:Kids")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Kids Activities", @"default category Expense:Kids Activities")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Late Fee", @"default category Expense:Late Fee")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Laundry", @"default category Expense:Laundry")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Lawn & Garden", @"default category Expense:Lawn & Garden")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Life Insurance", @"default category Expense:Life Insurance")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Misc.", @"default category Expense:Misc.")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Mobile Phone", @"default category Expense:Mobile Phone")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Mortgage & Rent", @"default category Expense:Mortgage & Rent")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Mortgage Interest", @"default category Expense:Mortgage Interest")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Movies & DVDs", @"default category Expense:Movies & DVDs")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Music", @"default category Expense:Music")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Newspaper & Magazines", @"default category Expense:Newspaper & Magazines")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Not Sure", @"default category Expense:Not Sure")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Parking", @"default category Expense:Parking")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Personal Care", @"default category Expense:Personal Care")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Pet Food & Supplies", @"default category Expense:Pet Food & Supplies")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Pet Grooming", @"default category Expense:Pet Grooming")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Pets", @"default category Expense:Pets")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Pharmacy", @"default category Expense:Pharmacy")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Property", @"default category Expense:Property")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Public Transportation", @"default category Expense:Public Transportation")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Registration", @"default category Expense:Registration")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Rental Car & Taxi", @"default category Expense:Rental Car & Taxi")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Restaurants", @"default category Expense:Restaurants")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Service & Parts", @"default category Expense:Service & Parts")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Service Fee", @"default category Expense:Service Fee")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Shopping", @"default category Expense:Shopping")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Spa & Massage", @"default category Expense:Spa & Massage")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Sporting Goods", @"default category Expense:Sporting Goods")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Sports", @"default category Expense:Sports")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Student Loan", @"default category Expense:Student Loan")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Tax", @"default category Expense:Tax")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Television", @"default category Expense:Television")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Tolls", @"default category Expense:Tolls")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Toys", @"default category Expense:Toys")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Trade Commissions", @"default category Expense:Trade Commissions")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Travel", @"default category Expense:Travel")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Tuition", @"default category Expense:Tuition")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Utilities", @"default category Expense:Utilities")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Vacation", @"default category Expense:Vacation")];
        [arrayCategories addObject:NSLocalizedString(@"Expense:Vet", @"default category Expense:Vet")];
        
        //
        // Income categories
        //
        [arrayCategories addObject:NSLocalizedString(@"Income:Consulting Income", @"default category Income:Consulting Income")];
        [arrayCategories addObject:NSLocalizedString(@"Income:Div Income", @"default category Income:Div Income")];
        [arrayCategories addObject:NSLocalizedString(@"Income:Net Salary", @"default category Income:Net Salary")];
        [arrayCategories addObject:NSLocalizedString(@"Income:Other Income", @"default category Income:Other Income")];
        [arrayCategories addObject:NSLocalizedString(@"Income:Rent", @"default category Income:Rent")];
        [arrayCategories addObject:NSLocalizedString(@"Income:Sales", @"default category Income:Sales")];
        
        //
        // Exchange Categories
        //
        [arrayCategories addObject:NSLocalizedString(@"Exchange:Buy Bitcoin", @"default category Exchange:Buy Bitcoin")];
        [arrayCategories addObject:NSLocalizedString(@"Exchange:Sell Bitcoin", @"default category Exchange:Sell Bitcoin")];
        
        //
        // Transfer Categories
        //
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitcoin.de", @"default category Transfer:Bitcoin.de")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitfinex", @"default category Transfer:Bitfinex")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Bitstamp", @"default category Transfer:Bitstamp")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:BTC-e", @"default category Transfer:BTC-e")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:BTCChina", @"default category Transfer:BTCChina")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Bter", @"default category Transfer:Bter")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:CAVirtex", @"default category Transfer:CAVirtex")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Coinbase", @"default category Transfer:Coinbase")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:CoinMKT", @"default category Transfer:CoinMKT")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Huobi", @"default category Transfer:Huobi")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Kraken", @"default category Transfer:Kraken")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:MintPal", @"default category Transfer:MintPal")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:OKCoin", @"default category Transfer:OKCoin")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Vault of Satoshi", @"default category Transfer:Vault of Satoshi")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Airbitz", @"default category Transfer:Wallet:Airbitz")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Armory", @"default category Transfer:Wallet:Armory")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Bitcoin Core", @"default category Transfer:Wallet:Bitcoin Core")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Blockchain", @"default category Transfer:Wallet:Blockchain")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Electrum", @"default category Transfer:Wallet:Electrum")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Multibit", @"default category Transfer:Wallet:Multibit")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Mycelium", @"default category Transfer:Wallet:Mycelium")];
        [arrayCategories addObject:NSLocalizedString(@"Transfer:Wallet:Dark Wallet", @"default category Transfer:Wallet:Dark Wallet")];
        
        // add default categories to core
        for (int i = 0; i < [arrayCategories count]; i++)
        {
            NSString *strCategory = [arrayCategories objectAtIndex:i];
            [mutableArrayCategories addObject:strCategory];
            
            ABC_AddCategory([_account.name UTF8String],
                            [_account.password UTF8String],
                            (char *)[strCategory UTF8String], &error);
        }
    }
    else
    {
        // store them in our own array
        
        if (aszCategories && countCategories > 0)
        {
            for (int i = 0; i < countCategories; i++)
            {
                [mutableArrayCategories addObject:[NSString stringWithUTF8String:aszCategories[i]]];
            }
        }
        
    }
    
    // free the core categories
    if (aszCategories != NULL)
    {
        [ABCUtil freeStringArray:aszCategories count:countCategories];
    }
    
    NSArray *tempArray = [mutableArrayCategories sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // store the final as storted
    _categoryList = tempArray;
    
    return _categoryList;
}

- (NSError *)addCategory:(NSString *)category;
{
    NSError *nserror = nil;
    // check and see that it doesn't already exist
    if ([_categoryList indexOfObject:category] == NSNotFound)
    {
        // add the category to the core
        tABC_Error error;
        ABC_AddCategory([_account.name UTF8String],
                        [_account.password UTF8String],
                        (char *)[category UTF8String], &error);
        nserror = [ABCError makeNSError:error];
        _categoriesUpdated = YES;
    }
    return nserror;
}

- (NSError *)removeCategory:(NSString *)category;
{
    tABC_Error error;
    NSError *nserror = nil;
    ABC_RemoveCategory([_account.name UTF8String],
                       [_account.password UTF8String],
                       (char *)[category UTF8String], &error);
    nserror = [ABCError makeNSError:error];
    _categoriesUpdated = YES;
    return nserror;
}

// saves the categories to the core
- (NSError *)saveCategories:(NSArray *)arrayCategories;
{
    NSError *nserror = nil;
    NSError *nserrorRet = nil;
    NSMutableArray *saveArrayCategories = [NSMutableArray arrayWithArray:arrayCategories];
    
    // got through the existing categories
    for (NSString *strCategory in _categoryList)
    {
        // if this category is in our new list
        if ([saveArrayCategories containsObject:strCategory])
        {
            // remove it from our new list since it is already there
            [saveArrayCategories removeObject:strCategory];
        }
        else
        {
            // it doesn't exist in our new list so delete it from the core
            nserror = [self removeCategory:strCategory];
            if (nserror) nserrorRet = nserror;
        }
    }
    
    // add any categories from our new list that didn't exist in the core list
    for (NSString *strCategory in saveArrayCategories)
    {
        nserror = [self addCategory:strCategory];
        if (nserror) nserrorRet = nserror;
    }
    
    return nserrorRet;
}



@end