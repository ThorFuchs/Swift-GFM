// SPDX-License-Identifier: Apache-2.0
// SwiftGFM's optional extension. The upstream cmark sources are not modified.
#include "cmark-gfm.h"
#include "cmark-gfm-extension_api.h"
#include "buffer.h"
#include "chunk.h"
#include "parser.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  cmark_strbuf tex;
  cmark_strbuf original;
  int display;
  int closed;
} math_item;

typedef struct swiftgfm_math_context {
  cmark_syntax_extension *extension;
  const unsigned char *line;
  size_t line_content;
  size_t line_length;
  math_item **items;
  size_t count;
  size_t capacity;
  size_t scanned;
  size_t budget;
  int failed;
  int contains_table;
} swiftgfm_math_context;

static int ascii_space(unsigned char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f';
}

static void free_item(cmark_mem *mem, void *ptr) {
  math_item *item = ptr;
  cmark_strbuf_free(&item->tex);
  cmark_strbuf_free(&item->original);
  mem->free(item);
}

static math_item *make_item(cmark_mem *mem, int display) {
  math_item *item = mem->calloc(1, sizeof(*item));
  if (!item) return NULL;
  cmark_strbuf_init(mem, &item->tex, 0);
  cmark_strbuf_init(mem, &item->original, 0);
  item->display = display;
  return item;
}

static cmark_node *math_inline(cmark_syntax_extension *ext, cmark_parser *parser,
                               cmark_node *parent, unsigned char ch,
                               cmark_inline_parser *inlines) {
  swiftgfm_math_context *ctx = cmark_syntax_extension_get_private(ext);
  if (ctx->failed || ch != '$' || cmark_inline_parser_in_bracket(inlines, 1)) return NULL;
  const char *parent_type = cmark_node_get_type_string(parent);
  if (parent_type && strcmp(parent_type, "table_cell") == 0) return NULL;
  cmark_chunk *chunk = cmark_inline_parser_get_chunk(inlines);
  int start = cmark_inline_parser_get_offset(inlines);
  if (start + 1 >= chunk->len || chunk->data[start + 1] == '$' ||
      ascii_space(chunk->data[start + 1]) || (start > 0 && chunk->data[start - 1] == '$')) return NULL;
  int escaped = 0;
  for (int i = start + 1; i < chunk->len && chunk->data[i] != '\n' && chunk->data[i] != '\r'; i++) {
    if (++ctx->scanned > ctx->budget) { ctx->failed = 1; return NULL; }
    unsigned char c = chunk->data[i];
    if (c == '$' && !escaped && i > start + 1 && !ascii_space(chunk->data[i - 1]) &&
        (i + 1 == chunk->len || (chunk->data[i + 1] != '$' &&
         !(chunk->data[i + 1] >= '0' && chunk->data[i + 1] <= '9')))) {
      cmark_node *node = cmark_node_new_with_mem(CMARK_NODE_CUSTOM_INLINE, parser->mem);
      math_item *item = make_item(parser->mem, 0);
      if (!node || !item) { if (node) cmark_node_free(node); if (item) free_item(parser->mem, item); ctx->failed = 1; return NULL; }
      cmark_strbuf_put(&item->tex, chunk->data + start + 1, i - start - 1);
      cmark_strbuf_put(&item->original, chunk->data + start, i - start + 1);
      item->closed = 1;
      cmark_node_set_user_data(node, item);
      cmark_node_set_user_data_free_func(node, free_item);
      cmark_inline_parser_set_offset(inlines, i + 1);
      return node;
    }
    /* The first unescaped dollar must close this span; never jump across a
       failed delimiter (for example, the second price in "$12 and $34"). */
    if (c == '$' && !escaped) break;
    if (c == '\\') escaped = !escaped; else escaped = 0;
  }
  return NULL;
}

static int fence_line(unsigned char *input, int len, int first) {
  if (first + 2 > len || input[first] != '$' || input[first + 1] != '$') return 0;
  for (int i = first + 2; i < len; i++)
    if (input[i] != ' ' && input[i] != '\t' && input[i] != '\n' && input[i] != '\r') return 0;
  return 1;
}

static void consume_line(cmark_parser *parser, unsigned char *input, int len) {
  int n = len - 1 - cmark_parser_get_offset(parser);
  if (n > 0) cmark_parser_advance_offset(parser, (char *)input, n, 0);
}

static cmark_node *math_open(cmark_syntax_extension *ext, int indented, cmark_parser *parser,
                             cmark_node *parent, unsigned char *input, int len) {
  swiftgfm_math_context *ctx = cmark_syntax_extension_get_private(ext);
  int first = cmark_parser_get_first_nonspace(parser);
  if (ctx->failed || indented || first + 2 > len || input[first] != '$' || input[first + 1] != '$') return NULL;
  int fence = fence_line(input, len, first);
  size_t last = ctx->line_content;
  while (last > (size_t)first && (ctx->line[last - 1] == ' ' || ctx->line[last - 1] == '\t')) last--;
  int oneline = !fence && last > (size_t)first + 4 && ctx->line[last - 1] == '$' && ctx->line[last - 2] == '$';
  if (oneline && (ctx->line[first + 2] == '$' || ctx->line[last - 3] == '$')) oneline = 0;
  if (oneline) {
    size_t backslashes = 0, i = last - 2;
    while (i > (size_t)first + 2 && ctx->line[i - 1] == '\\') { backslashes++; i--; }
    if (backslashes % 2) oneline = 0;
  }
  if (!fence && !oneline) return NULL;
  if ((size_t)first > ctx->line_content) { ctx->failed = 1; return NULL; }
  cmark_node *node = cmark_parser_add_child(parser, parent, CMARK_NODE_CUSTOM_BLOCK, first + 1);
  math_item *item = make_item(parser->mem, 1);
  if (!node || !item) { if (item) free_item(parser->mem, item); ctx->failed = 1; return NULL; }
  if (oneline) {
    cmark_strbuf_put(&item->tex, ctx->line + first + 2, (bufsize_t)(last - (size_t)first - 4));
    cmark_strbuf_put(&item->original, ctx->line + first, (bufsize_t)(last - (size_t)first));
    item->closed = 1;
  } else {
    cmark_strbuf_put(&item->original, ctx->line + first, (bufsize_t)(ctx->line_length - (size_t)first));
  }
  cmark_node_set_user_data(node, item);
  cmark_node_set_user_data_free_func(node, free_item);
  cmark_node_set_syntax_extension(node, ext);
  consume_line(parser, input, len);
  return node;
}

static int math_continue(cmark_syntax_extension *ext, cmark_parser *parser,
                         unsigned char *input, int len, cmark_node *node) {
  swiftgfm_math_context *ctx = cmark_syntax_extension_get_private(ext);
  math_item *item = cmark_node_get_user_data(node);
  if (item->closed) return 0;
  int offset = cmark_parser_get_offset(parser);
  int first = cmark_parser_get_first_nonspace(parser);
  if (offset < 0 || (size_t)offset > ctx->line_content) { ctx->failed = 1; return 0; }
  int closed = fence_line(input, len, first);
  if (closed) {
    cmark_strbuf_put(&item->original, ctx->line + offset, (bufsize_t)(ctx->line_content - (size_t)offset));
    item->closed = 1;
  } else {
    cmark_strbuf_put(&item->tex, ctx->line + offset, (bufsize_t)(ctx->line_length - (size_t)offset));
    cmark_strbuf_put(&item->original, ctx->line + offset, (bufsize_t)(ctx->line_length - (size_t)offset));
  }
  consume_line(parser, input, len);
  return !closed;
}

swiftgfm_math_context *swiftgfm_math_new(size_t source_size) {
  cmark_mem *mem = cmark_get_default_mem_allocator();
  swiftgfm_math_context *ctx = mem->calloc(1, sizeof(*ctx));
  if (!ctx) return NULL;
  ctx->budget = source_size > (SIZE_MAX - 1024) / 64 ? SIZE_MAX : source_size * 64 + 1024;
  ctx->extension = cmark_syntax_extension_new("swiftgfm-math");
  cmark_syntax_extension_set_private(ctx->extension, ctx, NULL);
  cmark_syntax_extension_set_match_inline_func(ctx->extension, math_inline);
  cmark_syntax_extension_set_open_block_func(ctx->extension, math_open);
  cmark_syntax_extension_set_match_block_func(ctx->extension, math_continue);
  cmark_llist *chars = cmark_llist_append(mem, NULL, (void *)(uintptr_t)'$');
  cmark_syntax_extension_set_special_inline_chars(ctx->extension, chars);
  return ctx;
}

int swiftgfm_math_attach(swiftgfm_math_context *ctx, cmark_parser *parser) {
  return cmark_parser_attach_syntax_extension(parser, ctx->extension);
}

cmark_node *swiftgfm_math_parse(swiftgfm_math_context *ctx, cmark_parser *parser, const char *input, size_t length) {
  size_t pos = 0;
  while (pos < length) {
    size_t end = pos;
    while (end < length && input[end] != '\n' && input[end] != '\r') end++;
    size_t next = end;
    if (next < length && input[next++] == '\r' && next < length && input[next] == '\n') next++;
    ctx->line = (const unsigned char *)input + pos;
    ctx->line_content = end - pos;
    ctx->line_length = next - pos;
    cmark_parser_feed(parser, input + pos, next - pos);
    pos = next;
  }
  return cmark_parser_finish(parser);
}

int swiftgfm_math_prepare(swiftgfm_math_context *ctx, cmark_node *root, const char *nonce) {
  cmark_mem *mem = cmark_get_default_mem_allocator();
  cmark_iter *iter = cmark_iter_new(root);
  cmark_event_type event;
  size_t image_depth = 0;
  while ((event = cmark_iter_next(iter)) != CMARK_EVENT_DONE) {
    cmark_node *node = cmark_iter_get_node(iter);
    cmark_node_type type = cmark_node_get_type(node);
    if (type == CMARK_NODE_IMAGE) {
      if (event == CMARK_EVENT_ENTER) image_depth++;
      else if (event == CMARK_EVENT_EXIT) image_depth--;
    }
    if (event != CMARK_EVENT_ENTER) continue;
    const char *name = cmark_node_get_type_string(node);
    if (name && strcmp(name, "table") == 0) ctx->contains_table = 1;
    if ((type != CMARK_NODE_CUSTOM_INLINE && type != CMARK_NODE_CUSTOM_BLOCK) || !cmark_node_get_user_data(node)) continue;
    math_item *item = cmark_node_get_user_data(node);
    if (!item->closed) { ctx->failed = 2; break; }
    if (image_depth) { ctx->failed = 3; break; }
    if (ctx->count == ctx->capacity) {
      size_t capacity = ctx->capacity ? ctx->capacity * 2 : 16;
      if (capacity < ctx->capacity || capacity > SIZE_MAX / sizeof(*ctx->items)) { ctx->failed = 1; break; }
      math_item **next = mem->realloc(ctx->items, capacity * sizeof(*next));
      if (!next) { ctx->failed = 1; break; }
      ctx->items = next;
      ctx->capacity = capacity;
    }
    ctx->items[ctx->count] = item;
    char marker[128];
    int n = snprintf(marker, sizeof(marker), "SWIFTGFMMATH%sZ%zuEND", nonce, ctx->count);
    if (n < 0 || (size_t)n >= sizeof(marker) || !cmark_node_set_on_enter(node, marker)) { ctx->failed = 1; break; }
    ctx->count++;
  }
  cmark_iter_free(iter);
  return ctx->failed;
}
size_t swiftgfm_math_count(swiftgfm_math_context *ctx) { return ctx->count; }
int swiftgfm_math_contains_table(swiftgfm_math_context *ctx) { return ctx->contains_table; }
const char *swiftgfm_math_tex(swiftgfm_math_context *ctx, size_t i) { return (char *)cmark_strbuf_cstr(&ctx->items[i]->tex); }
const char *swiftgfm_math_original(swiftgfm_math_context *ctx, size_t i) { return (char *)cmark_strbuf_cstr(&ctx->items[i]->original); }
int swiftgfm_math_display(swiftgfm_math_context *ctx, size_t i) { return ctx->items[i]->display; }
void swiftgfm_math_free(swiftgfm_math_context *ctx) {
  cmark_mem *mem = cmark_get_default_mem_allocator();
  if (!ctx) return;
  mem->free(ctx->items);
  cmark_syntax_extension_free(mem, ctx->extension);
  mem->free(ctx);
}
