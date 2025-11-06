#include <stdio.h>
#include <string.h>

#include "config.h"
#include "update.h"
#include "sockfuncs.h"
#include "url.h"

char new_version[16];

int update_check_for_new_version(void)
{
    int ret;
    char response[1024];

    memset(new_version, 0, sizeof(new_version));

    ret = url_get("http://danielnoethen.de/latest_butt", NULL, response, sizeof(response));

    if (ret <= 0) {
        return UPDATE_ILLEGAL_ANSWER;
    }

    response[ret] = '\0';

    char *p = strstr(response, "version: ");
    if (p == NULL) {
        return UPDATE_ILLEGAL_ANSWER;
    }

    p += strlen("version: ");

    if (p[strlen(p) - 1] == '\n') {
        p[strlen(p) - 1] = '\0';
    }

    int major_cur, minor_cur, patch_cur;
    int major_new, minor_new, patch_new;
    sscanf(VERSION, "%d.%d.%d", &major_cur, &minor_cur, &patch_cur);
    sscanf(p, "%d.%d.%d", &major_new, &minor_new, &patch_new);

    if ((major_new > major_cur) || (major_new == major_cur && minor_new > minor_cur) ||
        (major_new == major_cur && minor_new == minor_cur && patch_new > patch_cur)) {
        snprintf(new_version, sizeof(new_version) - 1, "%s", p);
        return UPDATE_NEW_VERSION;
    }

    return UPDATE_UP_TO_DATE;
}

char *update_get_version(void)
{
    return new_version;
}
