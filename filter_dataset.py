import pandas as pd

print("Loading dataset...")
# Using your exact absolute file path
file_path = r"C:\Users\yash2\OneDrive\Documents\PROJECTS\PBL ICML PROJECT\WaferAI_Dataset_Sample.xlsx"
df = pd.read_excel(file_path)

print(f"Original size: {len(df)} wafers")

# Filter out rows where there is no defect
df_defects = df[df['Defect_Pattern'] != 'None']

print(f"Filtered size: {len(df_defects)} defective wafers")

# Save the model-ready dataset
df_defects.to_excel("Cleaned_Defects_Only.xlsx", index=False)
print("Successfully saved Cleaned_Defects_Only.xlsx")
