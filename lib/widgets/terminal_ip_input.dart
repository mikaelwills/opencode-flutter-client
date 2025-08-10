import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';
import '../models/opencode_instance.dart';

enum TerminalIPInputMode {
  editable,    // For current connection - editable IP/port
  instance,    // For saved instances - shows name + IP:port
}

class TerminalIPInput extends StatelessWidget {
  final TerminalIPInputMode mode;
  final TextEditingController? ipController;
  final TextEditingController? portController;
  final OpenCodeInstance? instance;
  final VoidCallback? onConnect;
  final VoidCallback? onEdit;
  final String? ipHint;
  final String? portHint;
  final bool isConnecting;
  final double? maxWidth;

  const TerminalIPInput.editable({
    super.key,
    required this.ipController,
    required this.portController,
    this.onConnect,
    this.ipHint = 'IP Address',
    this.portHint = 'Port',
    this.isConnecting = false,
    this.maxWidth = 300,
  })  : mode = TerminalIPInputMode.editable,
        instance = null,
        onEdit = null;

  const TerminalIPInput.instance({
    super.key,
    required this.instance,
    this.onConnect,
    this.onEdit,
    this.isConnecting = false,
    this.maxWidth,
  })  : mode = TerminalIPInputMode.instance,
        ipController = null,
        portController = null,
        ipHint = null,
        portHint = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      child: Row(
        children: [
          if (mode == TerminalIPInputMode.instance && onEdit != null) ...[
            _buildEditButton(),
            const SizedBox(width: 12),
          ],
          Expanded(child: _buildTerminalInput()),
          const SizedBox(width: 12),
          _buildConnectButton(),
        ],
      ),
    );
  }

  Widget _buildTerminalInput() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: OpenCodeTheme.primary,
            width: 2,
          ),
          right: BorderSide(
            color: OpenCodeTheme.primary,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '❯',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildInputContent()),
        ],
      ),
    );
  }

  Widget _buildInputContent() {
    if (mode == TerminalIPInputMode.instance && instance != null) {
      return _buildInstanceDisplay();
    }
    return _buildEditableFields();
  }

  Widget _buildInstanceDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          instance!.name,
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: OpenCodeTheme.text,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          instance!.displayAddress,
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 12,
            color: OpenCodeTheme.text.withOpacity(0.7),
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEditableFields() {
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: TextField(
            controller: ipController,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
              hintText: ipHint,
              hintStyle: const TextStyle(
                color: OpenCodeTheme.textSecondary,
              ),
            ),
            maxLines: 1,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            ':',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          flex: 1,
          child: TextField(
            controller: portController,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
              hintText: portHint,
              hintStyle: const TextStyle(
                color: OpenCodeTheme.textSecondary,
              ),
            ),
            maxLines: 1,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: OpenCodeTheme.background,
        border: Border.all(
          color: OpenCodeTheme.primary.withOpacity(0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: OpenCodeTheme.primary.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnecting ? null : onConnect,
          borderRadius: BorderRadius.circular(4),
          splashColor: OpenCodeTheme.primary.withOpacity(0.1),
          highlightColor: OpenCodeTheme.primary.withOpacity(0.05),
          child: Center(
            child: isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        OpenCodeTheme.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.link,
                    size: 18,
                    color: OpenCodeTheme.primary,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: OpenCodeTheme.background,
        border: Border.all(
          color: OpenCodeTheme.text.withOpacity(0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: OpenCodeTheme.text.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(4),
          splashColor: OpenCodeTheme.text.withOpacity(0.1),
          highlightColor: OpenCodeTheme.text.withOpacity(0.05),
          child: Center(
            child: Icon(
              Icons.edit_outlined,
              size: 18,
              color: OpenCodeTheme.text.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

}