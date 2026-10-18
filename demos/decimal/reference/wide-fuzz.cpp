// Command line front end for VM/src/lwide.h, driven by wide-fuzz.py.
// Reads lines such as "add <a> <b>" (numbers in decimal) from stdin and prints the result of each on one line.
//
//   c++ -std=c++17 -O2 -I VM/src demos/decimal/reference/wide-fuzz.cpp -o /tmp/wide-fuzz
#include "lwide.h"

#include <cstdio>
#include <cstring>
#include <string>

static Wide parse(const char* s)
{
    Wide r = wideZero();
    for (; *s >= '0' && *s <= '9'; s++)
        r = wideAdd(wideMulSmall(r, 10), wideFromU64(uint64_t(*s - '0')));
    return r;
}

static std::string format(Wide a)
{
    if (wideIsZero(a))
        return "0";

    std::string out;
    while (!wideIsZero(a))
    {
        uint32_t rem;
        a = wideDivSmall(a, 1000000000u, &rem);
        char chunk[16];
        snprintf(chunk, sizeof(chunk), wideIsZero(a) ? "%u" : "%09u", rem);
        out.insert(0, chunk);
    }
    return out;
}

int main()
{
    char op[32], a[128], b[128];
    char line[512];
    while (fgets(line, sizeof(line), stdin))
    {
        a[0] = b[0] = 0;
        if (sscanf(line, "%31s %127s %127s", op, a, b) < 2)
            continue;

        Wide x = parse(a);
        Wide y = parse(b);

        if (!strcmp(op, "add"))
            puts(format(wideAdd(x, y)).c_str());
        else if (!strcmp(op, "sub"))
            puts(format(wideSub(x, y)).c_str());
        else if (!strcmp(op, "mul"))
            puts(format(wideMul(x, y)).c_str());
        else if (!strcmp(op, "mulsmall"))
            puts(format(wideMulSmall(x, uint32_t(strtoul(b, nullptr, 10)))).c_str());
        else if (!strcmp(op, "divmod"))
        {
            Wide q, r;
            wideDivMod(x, y, &q, &r);
            printf("%s %s\n", format(q).c_str(), format(r).c_str());
        }
        else if (!strcmp(op, "cmp"))
            printf("%d\n", wideCmp(x, y));
        else if (!strcmp(op, "digits"))
            printf("%d\n", wideDigits(x));
        else if (!strcmp(op, "bits"))
            printf("%d\n", wideBitLength(x));
        else if (!strcmp(op, "pow10"))
            puts(format(widePow10(atoi(a))).c_str());
        else
            puts("?");
    }
    return 0;
}
