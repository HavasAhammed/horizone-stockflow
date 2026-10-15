import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? editCustomer;

  const AddCustomerScreen({super.key, this.editCustomer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _consumerController;
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _consumerController = TextEditingController(
        text: widget.editCustomer?.consumerNumber ?? '');
    _phoneController =
        TextEditingController(text: widget.editCustomer?.phone ?? '');
    _nameController =
        TextEditingController(text: widget.editCustomer?.name ?? '');
    _addressController =
        TextEditingController(text: widget.editCustomer?.address ?? '');
  }

  @override
  void dispose() {
    _consumerController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (widget.editCustomer != null) {
        final updated = widget.editCustomer!.copyWith(
          consumerNumber: _consumerController.text.trim(),
          phone: _phoneController.text.trim(),
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        );
        await context.read<CustomerProvider>().updateCustomer(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer profile updated successfully.'),
              backgroundColor: AppColors.solarGreenDark,
            ),
          );
          Navigator.of(context).pop(updated);
        }
      } else {
        final newCust = await context.read<CustomerProvider>().addCustomer(
              consumerNumber: _consumerController.text.trim(),
              phone: _phoneController.text.trim(),
              name: _nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim(),
              address: _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim(),
            );
        if (mounted) {
          context.read<DashboardProvider>().loadDashboard();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Customer "${newCust.name ?? newCust.consumerNumber}" registered successfully.'),
              backgroundColor: AppColors.solarGreenDark,
            ),
          );
          Navigator.of(context).pop(newCust);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editCustomer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add KSEB Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _consumerController,
              decoration: const InputDecoration(
                labelText: 'KSEB Consumer Number (Mandatory) *',
                hintText: 'e.g. 1155443322110',
                prefixIcon: Icon(Icons.bolt, color: AppColors.solarAmber),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'KSEB Consumer Number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Unique 13-digit consumer number issued by Kerala State Electricity Board.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Mandatory) *',
                hintText: 'e.g. +91 98470 12345',
                prefixIcon: Icon(Icons.phone),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name (Optional)',
                hintText: 'e.g. Venu Gopal Nair',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Site Address (Optional)',
                hintText: 'Installation address, post office, district...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isEditing ? 'Update Customer' : 'Register Customer',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
