/*
 *  testPriv.hpp
 *  test
 *
 *  Created by Marinus van der Lugt on 18/01/17.
 *  Copyright © 2017 Marinus van der Lugt. All rights reserved.
 *
 */

/* The classes below are not exported */
#pragma GCC visibility push(hidden)

class testPriv
{
    public:
    void HelloWorldPriv(const char *);
};

#pragma GCC visibility pop
