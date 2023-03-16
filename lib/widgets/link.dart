import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Link extends StatelessWidget {
  final String name;
  final Function? handler;

  const Link(this.name, this.handler, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => handler == null ? {} : handler!(),
      child: Text(
        name,
        style: GoogleFonts.roboto(
          color: Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
