#ifndef EXEC_LISTS_H
#define EXEC_LISTS_H
/*
**	$VER: lists.h 39.0 (15.10.1991)
**	Includes Release 45.1
**
**	Definitions and macros for use with Exec lists
**
**	(C) Copyright 1985-2001 Amiga, Inc.
**	    All Rights Reserved
*/

#ifndef EXEC_NODES_H
#include <exec/nodes.h>
#endif /* EXEC_NODES_H */

/*
 *  Full featured list header.
 */
struct  __attribute__((__packed__)) List {
   ULONG   lh_Head;      /* amiga ptr */
   ULONG   lh_Tail;      /* amiga ptr */
   ULONG   lh_TailPred;  /* amiga ptr */
   UBYTE   lh_Type;
   UBYTE   l_pad;
};	/* word aligned */

/*
 * Minimal List Header - no type checking
 */
struct  __attribute__((__packed__)) MinList {
   ULONG   mlh_Head;     /* amiga ptr */
   ULONG   mlh_Tail;     /* amiga ptr */
   ULONG   mlh_TailPred; /* amiga ptr */
};	/* longword aligned */


/*
 *	Check for the presence of any nodes on the given list.	These
 *	macros are even safe to use on lists that are modified by other
 *	tasks.	However; if something is simultaneously changing the
 *	list, the result of the test is unpredictable.
 *
 *	Unless you first arbitrated for ownership of the list, you can't
 *	_depend_ on the contents of the list.  Nodes might have been added
 *	or removed during or after the macro executes.
 *
 *		if( IsListEmpty(list) )		printf("List is empty\n");
 */
#define IsListEmpty(x) \
	( ((x)->lh_TailPred) == (struct Node *)(x) )

#define IsMsgPortEmpty(x) \
	( ((x)->mp_MsgList.lh_TailPred) == (struct Node *)(&(x)->mp_MsgList) )


#endif	/* EXEC_LISTS_H */
