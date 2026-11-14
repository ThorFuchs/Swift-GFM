/* SwiftGFM integration shim. The upstream cmark sources remain unchanged. */
#include "cmark-gfm.h"

int swiftgfm_bridge_node_get_type(cmark_node *node) {
    return (int)cmark_node_get_type(node);
}

int swiftgfm_bridge_node_get_list_type(cmark_node *node) {
    return (int)cmark_node_get_list_type(node);
}

int swiftgfm_bridge_node_get_list_delim(cmark_node *node) {
    return (int)cmark_node_get_list_delim(node);
}
