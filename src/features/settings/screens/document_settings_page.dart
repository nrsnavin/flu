import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/document_settings_controller.dart';

// ══════════════════════════════════════════════════════════════
//  DOCUMENT SETTINGS PAGE
//  Edit the company branding printed on PDFs (PO / DC / MRP).
// ══════════════════════════════════════════════════════════════
class DocumentSettingsPage extends StatelessWidget {
  const DocumentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DocumentSettingsController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Document Settings',
        subtitle: 'Branding shown on printed documents',
      ),
      body: Obx(() {
        if (ctrl.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(ctrl.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: ErpColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                      label: 'Retry', icon: Icons.refresh, onPressed: ctrl.load),
                ],
              ),
            ),
          );
        }
        return Form(
          key: ctrl.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: ctrl.companyCtrl,
                decoration: ErpDecorations.formInput('Company name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.taglineCtrl,
                decoration: ErpDecorations.formInput('Tagline'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.addressCtrl,
                maxLines: 3,
                decoration: ErpDecorations.formInput('Address (one line each)'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: ctrl.gstinCtrl,
                      decoration: ErpDecorations.formInput('GSTIN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: ctrl.phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: ErpDecorations.formInput('Phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: ErpDecorations.formInput('Email'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.websiteCtrl,
                decoration: ErpDecorations.formInput('Website'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.accentCtrl,
                decoration: ErpDecorations.formInput('Accent colour (#RRGGBB)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.footerCtrl,
                maxLines: 2,
                decoration: ErpDecorations.formInput('Footer note'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl.termsCtrl,
                maxLines: 4,
                decoration: ErpDecorations.formInput('Terms & conditions'),
              ),
              const SizedBox(height: 22),
              Obx(() => ErpPrimaryButton(
                    label: 'Save settings',
                    icon: Icons.save_outlined,
                    isLoading: ctrl.saving.value,
                    onPressed: ctrl.save,
                  )),
              const SizedBox(height: 10),
              const Text(
                'The PDF template layout designer is available in the web app.',
                style: TextStyle(color: ErpColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      }),
    );
  }
}
