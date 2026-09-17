import plotly.graph_objects as go

def build_motor_twin(fault):
    fig = go.Figure(data=[go.Scatter3d(x=[0, 1], y=[0, 0], z=[0, 0], mode='lines', line=dict(width=10, color='blue'))])
    fig.update_layout(title=f"Motor Condition: {fault.upper()}")
    return fig