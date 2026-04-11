/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/file.h>
#include <errno.h>

#include "notify_rc.h"

static int is_regular_file(const char *path)
{
	struct stat st;
	return (stat(path, &st) == 0 && S_ISREG(st.st_mode));
}

static int name_in_list(char names[][NAME_MAX + 1], int count, const char *name)
{
	for (int i = 0; i < count; i++) {
		if (strcmp(names[i], name) == 0)
			return 1;
	}

	return 0;
}

static int marker_covers(const char *a, const char *b)
{
	for (int i = 0; marker_rules[i].name != NULL; i++) {
		if (strcmp(marker_rules[i].name, a) != 0)
			continue;

		for (int j = 0; marker_rules[i].covers[j] != NULL; j++) {
			if (strcmp(marker_rules[i].covers[j], b) == 0)
				return 1;
		}

		break;
	}

	return 0;
}

static int is_covered_by_present(char names[][NAME_MAX + 1], int count, const char *new_marker)
{
	for (int i = 0; i < count; i++) {
		if (marker_covers(names[i], new_marker))
			return 1;
	}

	return 0;
}

static int add_marker_normalized(const char *dirpath, const char *marker_name)
{
	DIR *dir;
	struct dirent *de;
	char present[MAX_MARKERS][NAME_MAX + 1];
	char fullpath[PATH_MAX];
	int present_count = 0;
	int already_exists = 0;
	int i, fd;

	dir = opendir(dirpath);
	if (!dir)
		return -1;

	while ((de = readdir(dir)) != NULL) {
		if (de->d_name[0] == '.')
			continue;

		if (present_count >= MAX_MARKERS)
			break;

		if (strlen(de->d_name) > NAME_MAX)
			continue;

		snprintf(fullpath, sizeof(fullpath), "%s/%s", dirpath, de->d_name);

		if (!is_regular_file(fullpath))
			continue;

		strncpy(present[present_count], de->d_name, NAME_MAX);
		present[present_count][NAME_MAX] = '\0';
		present_count++;
	}

	closedir(dir);

	if (name_in_list(present, present_count, marker_name))
		already_exists = 1;

	if (!already_exists && is_covered_by_present(present, present_count, marker_name))
		return 0;

	// Deleting everything that overlaps the new marker
	for (i = 0; i < present_count; i++) {
		if (marker_covers(marker_name, present[i])) {
			snprintf(fullpath, sizeof(fullpath), "%s/%s", dirpath, present[i]);
			unlink(fullpath);
		}
	}

	// Creating a new marker, if it doesn't exist yet
	if (!already_exists) {
		snprintf(fullpath, sizeof(fullpath), "%s/%s", dirpath, marker_name);
		fd = open(fullpath, O_CREAT | O_EXCL | O_WRONLY, 0644);
		if (fd < 0) {
			if (errno == EEXIST)
				return 0;
			return -1;
		}
		close(fd);
		return 1;
	}

	return 0;
}

static int notify_lock(void)
{
	int fd;

	fd = open("/var/lock/notify_rc.lock", O_CREAT | O_RDWR, 0644);
	if (fd < 0)
		return -1;

	if (flock(fd, LOCK_EX) != 0) {
		close(fd);
		return -1;
	}

	return fd;
}

static void notify_unlock(int lock_fd)
{
	if (lock_fd >= 0) {
		flock(lock_fd, LOCK_UN);
		close(lock_fd);
	}
}

static void notify_marker_create(const char *dir, const char *event_name)
{
	(void)add_marker_normalized(dir, event_name);
}

static void notify_rc_internal(const char *event_name, int wait_sec)
{
	int i, lock_fd;
	char full_name[PATH_MAX];

	lock_fd = notify_lock();

	if (lock_fd >= 0) {
		notify_marker_create(DIR_RC_INCOMPLETE, event_name);
		notify_marker_create(DIR_RC_NOTIFY, event_name);
		notify_unlock(lock_fd);
	} else {
		 // fallback
		notify_marker_create(DIR_RC_INCOMPLETE, event_name);
		notify_marker_create(DIR_RC_NOTIFY, event_name);
	}

	kill(1, SIGUSR1);

	if (wait_sec > 0) {
		snprintf(full_name, sizeof(full_name), "%s/%s",
			 DIR_RC_INCOMPLETE, event_name);

		for (i = 0; i < wait_sec; i++) {
			if (access(full_name, F_OK) != 0)
				break;
			sleep(1);
		}
	}
}

void notify_rc(const char *event_name)
{
	notify_rc_internal(event_name, 0);
}

void notify_rc_and_wait(const char *event_name, int wait_sec)
{
	notify_rc_internal(event_name, wait_sec);
}
