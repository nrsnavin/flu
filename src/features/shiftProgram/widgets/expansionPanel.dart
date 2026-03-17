import 'package:flutter/material.dart';


class ExpansionTileExample extends StatefulWidget {
   ExpansionTileExample({super.key});

  @override
  State<ExpansionTileExample> createState() => _ExpansionTileExampleState();
}

class _ExpansionTileExampleState extends State<ExpansionTileExample> {

  final purchaseNameController = TextEditingController();
  final purchaseEmailController = TextEditingController();
  final purchasePhoneController = TextEditingController();
  final accountsNameController = TextEditingController();
  final accountsEmailController = TextEditingController();
  final accountsPhoneController = TextEditingController();

  final merchandiserNameController = TextEditingController();
  final merchandiserEmailController = TextEditingController();
  final merchandiserPhoneController = TextEditingController();




  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
         ExpansionTile(
          title: Text('Add Purchase Contact'),
          children: <Widget>[
            TextFormField(
              controller: purchaseNameController,
              decoration:  InputDecoration(
                  labelText: "Purchase Contact Name",
                  hintText: "Enter  Purchase Contact Name",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),
            TextFormField(
              controller: purchaseEmailController,
              decoration: const InputDecoration(
                  labelText: "Purchase Email",
                  hintText: "Enter Purchase Email",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),

            TextFormField(
              controller: purchasePhoneController,
              decoration: const InputDecoration(
                  labelText: "Purchase Phone Number",
                  hintText: "Enter Purchase Phone Number",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),

          ],
        ),
        ExpansionTile(
          title: Text('Add Accounts Contact'),
          children:<Widget>[
            TextFormField(
              controller: accountsNameController,
              decoration:  InputDecoration(
                  labelText: "Acoounts Contact Name",
                  hintText: "Enter  Accounts Contact Name",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),
            TextFormField(
              controller: accountsEmailController,
              decoration: const InputDecoration(
                  labelText: "Accounts Email",
                  hintText: "Enter Acounts Email",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),

            TextFormField(
              controller: accountsPhoneController,
              decoration: const InputDecoration(
                  labelText: "Accounts Phone Number",
                  hintText: "Enter  Accounts Phonne NUmber",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),

          ],
        ),
        ExpansionTile(
          title: Text('Add Merchandiser Contact'),
          children:<Widget>[
            TextFormField(
              controller: merchandiserNameController,
              decoration:  InputDecoration(
                  labelText: "Merchandiser Contact Name",
                  hintText: "Enter  Merchandiser Contact Name",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),
            TextFormField(
              controller: merchandiserEmailController,
              decoration: const InputDecoration(
                  labelText: "Merchandiser Email",
                  hintText: "Enter Merchandiser Email",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),
            const SizedBox(
              height: 10,
            ),

            TextFormField(
              controller: merchandiserPhoneController,
              decoration: const InputDecoration(
                  labelText: "Merchandiser Phone Number",
                  hintText: "Enter Merchandiser Phone",
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.all(Radius.circular(2)))),
            ),

          ],
        ),




      ],
    );
  }
}
