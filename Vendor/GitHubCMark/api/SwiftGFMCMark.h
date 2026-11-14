#ifndef SWIFT_GFM_CMARK_BRIDGE_H
#define SWIFT_GFM_CMARK_BRIDGE_H
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Private SwiftPM integration declarations. Upstream source is unchanged. */
typedef struct cmark_parser swiftgfm_parser;
typedef struct cmark_node swiftgfm_node;
typedef struct cmark_syntax_extension swiftgfm_extension;
typedef struct _cmark_llist swiftgfm_llist;
const char *swiftgfm_cmark_version_string(void);
void swiftgfm_cmark_gfm_core_extensions_ensure_registered(void);
swiftgfm_parser *swiftgfm_cmark_parser_new(int options);
void swiftgfm_cmark_parser_free(swiftgfm_parser *parser);
void swiftgfm_cmark_parser_feed(swiftgfm_parser *parser, const char *buffer, size_t len);
swiftgfm_node *swiftgfm_cmark_parser_finish(swiftgfm_parser *parser);
swiftgfm_extension *swiftgfm_cmark_find_syntax_extension(const char *name);
int swiftgfm_cmark_parser_attach_syntax_extension(swiftgfm_parser *parser, swiftgfm_extension *extension);
swiftgfm_llist *swiftgfm_cmark_parser_get_syntax_extensions(swiftgfm_parser *parser);
void swiftgfm_cmark_node_free(swiftgfm_node *node);
swiftgfm_node *swiftgfm_cmark_node_first_child(swiftgfm_node *node);
swiftgfm_node *swiftgfm_cmark_node_next(swiftgfm_node *node);
/* Integer-returning wrappers are defined against the actual upstream enums. */
int swiftgfm_bridge_node_get_type(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_type_string(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_literal(swiftgfm_node *node);
int swiftgfm_cmark_node_get_heading_level(swiftgfm_node *node);
int swiftgfm_bridge_node_get_list_type(swiftgfm_node *node);
int swiftgfm_bridge_node_get_list_delim(swiftgfm_node *node);
int swiftgfm_cmark_node_get_list_start(swiftgfm_node *node);
int swiftgfm_cmark_node_get_list_tight(swiftgfm_node *node);
int swiftgfm_cmark_node_get_item_index(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_fence_info(swiftgfm_node *node);
int swiftgfm_cmark_node_get_fenced(swiftgfm_node *node, int *length, int *offset, char *character);
const char *swiftgfm_cmark_node_get_url(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_title(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_on_enter(swiftgfm_node *node);
const char *swiftgfm_cmark_node_get_on_exit(swiftgfm_node *node);
int swiftgfm_cmark_node_get_start_line(swiftgfm_node *node);
int swiftgfm_cmark_node_get_start_column(swiftgfm_node *node);
int swiftgfm_cmark_node_get_end_line(swiftgfm_node *node);
int swiftgfm_cmark_node_get_end_column(swiftgfm_node *node);
uint16_t swiftgfm_cmark_gfm_extensions_get_table_columns(swiftgfm_node *node);
uint8_t *swiftgfm_cmark_gfm_extensions_get_table_alignments(swiftgfm_node *node);
bool swiftgfm_cmark_gfm_extensions_get_tasklist_item_checked(swiftgfm_node *node);
char *swiftgfm_cmark_render_html(swiftgfm_node *root, int options, swiftgfm_llist *extensions);
char *swiftgfm_cmark_render_xml(swiftgfm_node *root, int options);
char *swiftgfm_cmark_render_commonmark(swiftgfm_node *root, int options, int width);
char *swiftgfm_cmark_render_plaintext(swiftgfm_node *root, int options, int width);
char *swiftgfm_cmark_render_latex(swiftgfm_node *root, int options, int width);
char *swiftgfm_cmark_render_man(swiftgfm_node *root, int options, int width);
#ifdef __cplusplus
}
#endif
#endif
