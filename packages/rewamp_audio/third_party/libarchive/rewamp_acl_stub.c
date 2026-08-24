/*
 * On ne construit aucun backend ACL sur Linux: le bloc __linux__ de config.h
 * laisse ARCHIVE_ACL_LIBACL / RICHACL indéfinis (bionic n'a pas les ACL
 * POSIX.1e, et sur glibc elles viennent de libacl, une dépendance dont
 * l'extraction de fichiers de musique n'a que faire). archive_disk_acl_linux.c
 * se compile donc VIDE — mais archive_write_disk_posix.c appelle toujours
 * archive_write_disk_set_acls(). D'où ce no-op, sans quoi le lien de la .so
 * échoue sur un symbole non défini que rien ne désigne comme venant des ACL.
 * Vide sur toute autre plateforme (Apple garde ses vrais backends).
 *
 * (Ne fait pas partie de libarchive amont — ajouté pour rewamp.)
 */
#ifdef __linux__
#include "archive_platform.h"
#include "archive_write_disk_private.h"

int
archive_write_disk_set_acls(struct archive *a, int fd, const char *name,
    struct archive_acl *abstract_acl, __LA_MODE_T mode)
{
	(void)a; (void)fd; (void)name; (void)abstract_acl; (void)mode;
	return (ARCHIVE_OK);
}
#endif /* __linux__ */
