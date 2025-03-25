import 'package:flutter/material.dart';

class PaginatedGridList<T> extends StatefulWidget {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Function(T) onItemTap;
  final Function(T) onItemLongPress;
  final Widget Function(T) itemBuilder;
  final int crossAxisCount;
  final bool isList;
  final double? childAspectRatio;
  final ScrollController? scrollController;

  const PaginatedGridList({
    Key? key,
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.error,
    this.isList = false,
    this.childAspectRatio,
    this.scrollController,
  }) : super(key: key);

  @override
  State<PaginatedGridList<T>> createState() => _PaginatedGridListState<T>();
}

class _PaginatedGridListState<T> extends State<PaginatedGridList<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!widget.isLoading && widget.hasMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && !widget.isLoading) {
      return Center(
        child: widget.error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              )
            : const Text('No items found'),
      );
    }

    if (widget.isList) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.items.length) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final item = widget.items[index];
          return GestureDetector(
            onTap: () => widget.onItemTap(item),
            onLongPress: () => widget.onItemLongPress(item),
            child: widget.itemBuilder(item),
          );
        },
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio ?? 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final item = widget.items[index];
        return GestureDetector(
          onTap: () => widget.onItemTap(item),
          onLongPress: () => widget.onItemLongPress(item),
          child: widget.itemBuilder(item),
        );
      },
    );
  }
} 